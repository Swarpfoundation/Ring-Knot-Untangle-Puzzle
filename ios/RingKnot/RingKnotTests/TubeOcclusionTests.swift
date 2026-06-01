import XCTest
@testable import RingKnot

/// Phase 6C — neighbour-aware contact bands + tube occlusion metadata.
final class TubeOcclusionTests: XCTestCase {

    private func shipped() throws -> LevelPack {
        try TestBundleHelper.loadShippedPack()
    }

    // MARK: - isContactBand classification

    func testContactBandClassification() {
        // A clip with a contact ring or non-owner placement is a scene-level band.
        let band = BlockerClip(id: "K", ownerRingId: "S1", angleDegrees: 0,
                               contactRingId: "C1", contactPointMode: .betweenCenters)
        XCTAssertTrue(band.isContactBand)
        // A legacy owner-attached clip stays a rolling clip.
        let rolling = BlockerClip(id: "K2", ownerRingId: "S1", angleDegrees: 0)
        XCTAssertFalse(rolling.isContactBand)
    }

    // MARK: - Neighbour-aware geometry has valid owner + contact rings

    func testEveryContactBandHasResolvableOwnerAndContact() throws {
        for level in try shipped().levels {
            let ringIDs = Set(level.rings.map(\.id))
            for clip in level.clips where clip.isContactBand {
                XCTAssertTrue(ringIDs.contains(clip.ownerRingId),
                              "Level \(level.id) clip \(clip.id) owner missing")
                if let contact = clip.contactRingId {
                    XCTAssertTrue(ringIDs.contains(contact),
                                  "Level \(level.id) clip \(clip.id) contact \(contact) missing")
                    XCTAssertNotEqual(contact, clip.ownerRingId,
                                      "Level \(level.id) clip \(clip.id) contacts itself")
                }
            }
        }
    }

    // MARK: - bridgeBand requires a contact ring

    func testBridgeBandsHaveContactRing() throws {
        for level in try shipped().levels {
            for clip in level.clips where clip.clampStyle == .bridgeBand {
                XCTAssertNotNil(clip.contactRingId,
                                "Level \(level.id) bridgeBand \(clip.id) has no contactRingId")
            }
        }
    }

    // MARK: - No dependency interlock is decorative

    func testNoDependencyInterlockIsDecorative() throws {
        for level in try shipped().levels {
            let depEdges = Set(level.rings.flatMap { r in r.requires.map { "\($0)->\(r.id)" } })
            for lock in level.interlocks {
                let edge = "\(lock.blockerRingId)->\(lock.blockedRingId)"
                if depEdges.contains(edge) {
                    XCTAssertTrue(lock.visualContactMode.explainsDependency,
                        "Level \(level.id) dependency interlock \(lock.id) is decorative")
                }
            }
        }
    }

    // MARK: - Blocked feedback resolves the exact blocker clip

    func testBlockedFeedbackResolvesExactBlockerClip() throws {
        for level in try shipped().levels {
            for ring in level.rings {
                for blocker in ring.requires {
                    let holding = level.clipsBlocking(ring.id)
                        .filter { $0.ownerRingId == blocker }
                    XCTAssertFalse(holding.isEmpty,
                        "Level \(level.id) no clip identifies \(blocker) holding \(ring.id)")
                }
            }
        }
    }

    // MARK: - Level 1 + Level 20 content

    func testLevel1HasAContactClipWithContactRing() throws {
        let level = try shipped().levels.first { $0.id == 1 }!
        let contactClips = level.clips.filter { $0.isContactBand && $0.contactRingId != nil }
        XCTAssertFalse(contactClips.isEmpty, "Level 1 should have a neighbour-aware contact clip")
    }

    func testLevel20HasMultipleNeighbourAwareBridges() throws {
        let level = try shipped().levels.first { $0.id == 20 }!
        let bridges = level.clips.filter { $0.contactRingId != nil &&
            ($0.clampStyle == .bridgeBand || $0.depthRole == .bridge) }
        XCTAssertGreaterThanOrEqual(bridges.count, 2,
            "Level 20 should have multiple neighbour-aware bridge clips")
        // And plenty of contact bands overall for a dense, physical board.
        let contactBands = level.clips.filter { $0.isContactBand }
        XCTAssertGreaterThanOrEqual(contactBands.count, 10)
    }
}
