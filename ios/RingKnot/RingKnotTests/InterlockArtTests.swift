import XCTest
@testable import RingKnot

/// Phase 6B — interlock geometry + art-polish metadata.
final class InterlockArtTests: XCTestCase {

    private func shipped() throws -> LevelPack {
        try TestBundleHelper.loadShippedPack()
    }

    // MARK: - depthRole / clampStyle / contactPointMode defaults

    func testClipDepthRoleDefaultsFromKind() {
        let blocker = BlockerClip(id: "K1", ownerRingId: "S1", angleDegrees: 0, kind: .blocker)
        let connector = BlockerClip(id: "K2", ownerRingId: "A1", angleDegrees: 0, kind: .connector)
        let bridge = BlockerClip(id: "K3", ownerRingId: "C1", angleDegrees: 0, kind: .bridge)
        XCTAssertEqual(blocker.depthRole, .over)
        XCTAssertEqual(connector.depthRole, .connector)
        XCTAssertEqual(bridge.depthRole, .bridge)
        // Defaults for the other 6B fields.
        XCTAssertEqual(blocker.contactPointMode, .ownerAngle)
        XCTAssertEqual(blocker.visualLayer, .foreground)
        XCTAssertEqual(connector.visualLayer, .midground)
        XCTAssertEqual(bridge.clampStyle, .bridgeBand)
        XCTAssertFalse(blocker.blocksExitDirection)
    }

    func testInterlockVisualContactModeDefaultsAndDecorativeFlag() {
        let il = Interlock(id: "IL", blockerRingId: "S1", blockedRingId: "C1",
                           blockerClipId: "K1", contactAngleDegrees: 0)
        XCTAssertEqual(il.visualContactMode, .clipBlocksGap)
        XCTAssertTrue(il.visualContactMode.explainsDependency)
        XCTAssertFalse(InterlockVisualContactMode.decorativeConnector.explainsDependency)
    }

    // MARK: - JSON parsing of 6B fields

    func testParsesPhase6BClipAndInterlockFields() throws {
        let json = """
        {"game":"t","version":"1","levels":[{"id":1,"name":"x","board":{"rows":5,"cols":5},
          "pieces":[
            {"id":"S1","kind":"silver","cell":"B3","exitDirection":"N","requires":[],"initialGapAngle":150},
            {"id":"C1","kind":"copper","cell":"C3","exitDirection":"E","requires":["S1"],"initialGapAngle":285},
            {"id":"A1","kind":"silver","cell":"B2","exitDirection":"N","requires":[],"bodyType":"closedAnchor","removable":false}
          ],
          "clips":[
            {"id":"K1","ownerRingId":"S1","angleDegrees":270,"kind":"blocker","blocksRingIds":["C1"],
             "depthRole":"over","contactRingId":"C1","contactPointMode":"betweenCenters",
             "visualLayer":"foreground","clampStyle":"rivetedBand","blocksExitDirection":true,
             "explicitPositionOffset":{"x":0.1,"y":-0.2}},
            {"id":"KA","ownerRingId":"A1","angleDegrees":0,"kind":"connector","clampStyle":"wideBand"}
          ],
          "interlocks":[{"id":"IL1","blockerRingId":"S1","blockedRingId":"C1","blockerClipId":"K1",
             "contactAngleDegrees":270,"visualContactMode":"clipBlocksGap",
             "requiredGapClearanceAngleDegrees":30,"contactDescription":"clear the clamp"}],
          "solution":[{"id":"S1","drag":"N"},{"id":"C1","drag":"E"}]}]}
        """
        let level = try LevelLoader.decode(Data(json.utf8)).levels[0]
        let k1 = level.clips(forOwner: "S1").first!
        XCTAssertEqual(k1.depthRole, .over)
        XCTAssertEqual(k1.contactPointMode, .betweenCenters)
        XCTAssertEqual(k1.clampStyle, .rivetedBand)
        XCTAssertEqual(k1.contactRingId, "C1")
        XCTAssertTrue(k1.blocksExitDirection)
        XCTAssertEqual(k1.explicitPositionOffset?.x, 0.1)
        let ka = level.clips(forOwner: "A1").first!
        XCTAssertEqual(ka.clampStyle, .wideBand)
        let il = level.interlocks.first!
        XCTAssertEqual(il.visualContactMode, .clipBlocksGap)
        XCTAssertEqual(il.requiredGapClearanceAngleDegrees, 30)
        XCTAssertEqual(il.contactDescription, "clear the clamp")
    }

    func testInvalidEnumStringThrows() {
        let json = """
        {"game":"t","version":"1","levels":[{"id":1,"name":"x","board":{"rows":5,"cols":5},
          "pieces":[{"id":"C1","kind":"copper","cell":"C3","exitDirection":"E","requires":[],"initialGapAngle":285}],
          "clips":[{"id":"K1","ownerRingId":"C1","angleDegrees":0,"depthRole":"sideways"}],
          "solution":[{"id":"C1","drag":"E"}]}]}
        """
        XCTAssertThrowsError(try LevelLoader.decode(Data(json.utf8)))
    }

    // MARK: - Shipped-pack guarantees

    func testEveryDependencyHasNonDecorativeInterlock() throws {
        for level in try shipped().levels {
            let nonDecorativeEdges = Set(level.interlocks
                .filter { $0.visualContactMode.explainsDependency }
                .map { "\($0.blockerRingId)->\($0.blockedRingId)" })
            for ring in level.rings {
                for dep in ring.requires {
                    XCTAssertTrue(nonDecorativeEdges.contains("\(dep)->\(ring.id)"),
                        "Level \(level.id) dep \(dep)->\(ring.id) lacks a non-decorative interlock")
                }
            }
        }
    }

    func testNoShippedLevelUsesAbstractOnly() throws {
        for level in try shipped().levels {
            XCTAssertFalse(level.abstractOnly, "Level \(level.id) must not use abstractOnly")
        }
    }

    func testDependencyClipsUseContactPointGeometry() throws {
        // Every blocker clip that gates a dependency should point at a real
        // contact ring and sit at the contact rim, not arbitrarily on the owner.
        for level in try shipped().levels {
            for clip in level.clips where clip.kind == .blocker {
                XCTAssertEqual(clip.contactPointMode, .betweenCenters,
                               "Level \(level.id) blocker clip \(clip.id) not at contact rim")
                XCTAssertNotNil(clip.contactRingId)
                XCTAssertEqual(clip.depthRole, .over)
            }
        }
    }

    func testHintCanIdentifyBlockerClipForBlockedRing() throws {
        // For a blocked ring whose blocker carries a clip, the level can name the
        // clamp holding it (used by blocked feedback / hints).
        let level = try shipped().levels.first { $0.id == 1 }!
        // C1 requires S1; S1 carries a clip blocking C1.
        let holding = level.clipsBlocking("C1")
        XCTAssertFalse(holding.isEmpty, "no clip identified as blocking C1")
        XCTAssertTrue(holding.contains { $0.ownerRingId == "S1" })
    }

    func testAnchorsCarryConnectorOrBlockerClips() throws {
        for level in try shipped().levels {
            for anchor in level.anchors {
                let owned = level.clips(forOwner: anchor.id)
                XCTAssertFalse(owned.isEmpty, "Level \(level.id) anchor \(anchor.id) has no clip")
                XCTAssertTrue(owned.allSatisfy { $0.kind == .connector || $0.kind == .blocker },
                              "Level \(level.id) anchor \(anchor.id) clip kind unexpected")
            }
        }
    }
}
