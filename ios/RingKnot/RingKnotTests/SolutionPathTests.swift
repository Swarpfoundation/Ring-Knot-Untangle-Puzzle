import XCTest
@testable import RingKnot

final class SolutionPathTests: XCTestCase {

    func testAllShippedLevelsAreSolvableViaSolutionPath() throws {
        let pack = try TestBundleHelper.loadShippedPack()
        for level in pack.levels {
            try assertSolvable(level)
        }
    }

    func testEverySolutionStepUnlocksWhenAppliedInOrder() throws {
        let pack = try TestBundleHelper.loadShippedPack()
        for level in pack.levels {
            let validator = MoveValidator(level: level)
            var cleared = Set<String>()
            for step in level.solution {
                XCTAssertTrue(
                    validator.isUnlocked(ringId: step.ringId, clearedIds: cleared),
                    "Level \(level.id): step \(step.ringId) attempted while locked"
                )
                guard let ring = level.ring(step.ringId) else {
                    XCTFail("Level \(level.id) missing ring \(step.ringId)")
                    continue
                }
                XCTAssertEqual(
                    step.direction,
                    ring.exitDirection,
                    "Level \(level.id) step \(step.ringId) drag direction mismatch"
                )
                cleared.insert(step.ringId)
            }
        }
    }

    func testBlockedRingFailsBeforePrerequisitesCleared() throws {
        let pack = try TestBundleHelper.loadShippedPack()
        for level in pack.levels {
            for ring in level.rings where !ring.requires.isEmpty {
                var state = GameState(level: level)
                let outcome = state.attempt(ringId: ring.id, dragDirection: ring.exitDirection)
                if case .blockedByPrerequisite = outcome {} else {
                    XCTFail("Level \(level.id) ring \(ring.id) should be blocked initially, got \(outcome)")
                }
                XCTAssertFalse(state.clearedRingIds.contains(ring.id))
            }
        }
    }

    private func assertSolvable(_ level: Level) throws {
        var state = GameState(level: level)
        for step in level.solution {
            let outcome = state.attempt(ringId: step.ringId, dragDirection: step.direction)
            XCTAssertEqual(
                outcome,
                .accepted,
                "Level \(level.id) step \(step.ringId) rejected: \(outcome)"
            )
        }
        XCTAssertTrue(state.isComplete, "Level \(level.id) not complete after solution path")
        // The solution clears every *removable* ring; closed anchors stay put.
        XCTAssertEqual(
            state.clearedRingIds.count,
            level.removableRings.count,
            "Level \(level.id) did not clear every removable ring"
        )
        for anchor in level.anchors {
            XCTAssertFalse(
                state.clearedRingIds.contains(anchor.id),
                "Level \(level.id) anchor \(anchor.id) should remain after completion"
            )
        }
    }
}
