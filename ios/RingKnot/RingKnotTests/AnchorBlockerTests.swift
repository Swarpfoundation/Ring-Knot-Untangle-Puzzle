import XCTest
@testable import RingKnot

/// Phase 6A — closed anchors, blocker clips, and interlocks.
final class AnchorBlockerTests: XCTestCase {

    private func shipped() throws -> LevelPack {
        try TestBundleHelper.loadShippedPack()
    }

    private func level(_ id: Int) throws -> Level {
        try shipped().levels.first { $0.id == id }!
    }

    // MARK: - bodyType / removable parsing & defaulting

    func testRingDefaultsToOpenRemovable() {
        let ring = Ring(id: "S1", kind: .silver, cell: Cell(row: 1, col: 2),
                        exitDirection: .n, requires: [])
        XCTAssertEqual(ring.bodyType, .openRing)
        XCTAssertFalse(ring.isAnchor)
        XCTAssertTrue(ring.removable)
    }

    func testClosedAnchorDefaultsNonRemovable() {
        let ring = Ring(id: "A1", kind: .silver, cell: Cell(row: 0, col: 0),
                        exitDirection: .n, requires: [], bodyType: .closedAnchor)
        XCTAssertEqual(ring.bodyType, .closedAnchor)
        XCTAssertTrue(ring.isAnchor)
        XCTAssertFalse(ring.removable)
    }

    func testRemovableOverrideRespected() {
        let ring = Ring(id: "A1", kind: .silver, cell: Cell(row: 0, col: 0),
                        exitDirection: .n, requires: [], bodyType: .closedAnchor,
                        removable: true)
        XCTAssertTrue(ring.removable)
    }

    func testBodyTypeParsesFromJSON() throws {
        let json = """
        {"game":"t","version":"1","levels":[{"id":1,"name":"x","board":{"rows":5,"cols":5},
          "pieces":[
            {"id":"S1","kind":"silver","cell":"B3","exitDirection":"N","requires":[],"initialGapAngle":150},
            {"id":"C1","kind":"copper","cell":"C3","exitDirection":"E","requires":["S1"],"initialGapAngle":285},
            {"id":"A1","kind":"silver","cell":"B2","exitDirection":"N","requires":[],"bodyType":"closedAnchor","removable":false}
          ],
          "clips":[{"id":"K1","ownerRingId":"S1","angleDegrees":270,"kind":"blocker","blocksRingIds":["C1"]},
                   {"id":"KA","ownerRingId":"A1","angleDegrees":0,"kind":"connector"}],
          "interlocks":[{"id":"IL1","blockerRingId":"S1","blockedRingId":"C1","blockerClipId":"K1","contactAngleDegrees":270}],
          "solution":[{"id":"S1","drag":"N"},{"id":"C1","drag":"E"}]}]}
        """
        let pack = try LevelLoader.decode(Data(json.utf8))
        let level = pack.levels[0]
        XCTAssertTrue(level.ring("A1")!.isAnchor)
        XCTAssertFalse(level.ring("A1")!.removable)
        XCTAssertTrue(level.ring("S1")!.removable)
        XCTAssertEqual(level.clips.count, 2)
        XCTAssertEqual(level.interlocks.count, 1)
        XCTAssertEqual(level.anchors.map(\.id), ["A1"])
        XCTAssertEqual(level.clips(forOwner: "S1").first?.blocksRingIds, ["C1"])
    }

    // MARK: - completion ignores anchors

    func testCompletionIgnoresAnchors() throws {
        let level = try level(1)
        XCTAssertFalse(level.anchors.isEmpty, "Level 1 should have an anchor")
        var state = GameState(level: level)
        for step in level.solution {
            let outcome = state.attemptRelease(
                ringId: step.ringId,
                gapAngleDegrees: level.ring(step.ringId)!.targetExitAngleDegrees)
            XCTAssertEqual(outcome, .accepted)
        }
        XCTAssertTrue(state.isComplete, "level complete with the anchor still on the board")
        for anchor in level.anchors {
            XCTAssertFalse(state.clearedRingIds.contains(anchor.id))
        }
    }

    // MARK: - anchors cannot be released

    func testAnchorCannotBeReleased() throws {
        let level = try level(1)
        let anchor = level.anchors.first!
        let validator = MoveValidator(level: level)
        let release = validator.evaluateRelease(
            ringId: anchor.id, gapAngleDegrees: anchor.targetExitAngleDegrees, clearedIds: [])
        XCTAssertEqual(release, .notRemovable)
        let drag = validator.evaluate(
            ringId: anchor.id, dragDirection: anchor.exitDirection, clearedIds: [])
        XCTAssertEqual(drag, .notRemovable)
    }

    func testAttemptingAnchorDoesNotCountAsMove() throws {
        let level = try level(1)
        let anchor = level.anchors.first!
        var state = GameState(level: level)
        _ = state.attempt(ringId: anchor.id, dragDirection: anchor.exitDirection)
        _ = state.attemptRelease(ringId: anchor.id, gapAngleDegrees: anchor.targetExitAngleDegrees)
        XCTAssertEqual(state.moveCount, 0)
        XCTAssertFalse(state.clearedRingIds.contains(anchor.id))
    }

    // MARK: - hints ignore anchors

    func testHintsNeverSuggestAnchors() throws {
        for level in try shipped().levels {
            let validator = MoveValidator(level: level)
            var cleared = Set<String>()
            // Walk the whole solution; the suggested ring is never an anchor.
            for step in level.solution {
                if let suggested = validator.nextSuggestedRingId(clearedIds: cleared) {
                    XCTAssertFalse(level.ring(suggested)!.isAnchor,
                                   "Level \(level.id) suggested anchor \(suggested)")
                }
                cleared.insert(step.ringId)
            }
        }
    }

    // MARK: - every level has at least one anchor + complexity curve

    func testEveryLevelHasAnchorAndCurve() throws {
        let pack = try shipped()
        XCTAssertEqual(pack.levels.count, 20)
        for level in pack.levels {
            let count = level.anchors.count
            XCTAssertGreaterThanOrEqual(count, 1, "Level \(level.id) has no anchor")
            let need: Int
            switch level.id {
            case ...5:   need = 1
            case ...10:  need = 1
            case ...15:  need = 2
            default:     need = 3
            }
            XCTAssertGreaterThanOrEqual(count, need,
                "Level \(level.id) anchors \(count) < band minimum \(need)")
        }
    }

    // MARK: - referential integrity of clips & interlocks

    func testClipsAndInterlocksReferenceValidRings() throws {
        for level in try shipped().levels {
            let ringIDs = Set(level.rings.map(\.id))
            let clipIDs = Set(level.clips.map(\.id))
            for clip in level.clips {
                XCTAssertTrue(ringIDs.contains(clip.ownerRingId),
                              "Level \(level.id) clip \(clip.id) bad owner")
                for blocked in clip.blocksRingIds {
                    XCTAssertTrue(ringIDs.contains(blocked),
                                  "Level \(level.id) clip \(clip.id) blocks unknown \(blocked)")
                }
            }
            for lock in level.interlocks {
                XCTAssertTrue(ringIDs.contains(lock.blockerRingId))
                XCTAssertTrue(ringIDs.contains(lock.blockedRingId))
                XCTAssertTrue(clipIDs.contains(lock.blockerClipId),
                              "Level \(level.id) interlock \(lock.id) bad clip")
            }
        }
    }

    func testEveryAnchorHasAClip() throws {
        for level in try shipped().levels {
            let owners = Set(level.clips.map(\.ownerRingId))
            for anchor in level.anchors {
                XCTAssertTrue(owners.contains(anchor.id),
                              "Level \(level.id) anchor \(anchor.id) has no clip")
            }
        }
    }

    func testEveryDependencyHasAnInterlock() throws {
        for level in try shipped().levels where !level.abstractOnly {
            let edges = Set(level.interlocks.map { "\($0.blockerRingId)->\($0.blockedRingId)" })
            for ring in level.rings {
                for dep in ring.requires {
                    XCTAssertTrue(edges.contains("\(dep)->\(ring.id)"),
                                  "Level \(level.id) dep \(dep)->\(ring.id) has no interlock")
                }
            }
        }
    }

    func testSolutionReferencesRemovableRingsOnly() throws {
        for level in try shipped().levels {
            for step in level.solution {
                let ring = level.ring(step.ringId)!
                XCTAssertTrue(ring.removable, "Level \(level.id) solution step \(step.ringId) not removable")
                XCTAssertFalse(ring.isAnchor)
            }
        }
    }
}
