import XCTest
@testable import RingKnot

/// Phase 4A: the rotatable-ring release mechanic. A ring only leaves the board
/// once its gap is rolled into alignment with its exit direction *and* its
/// dependencies are cleared.
final class RingRotationTests: XCTestCase {

    // MARK: - Angle maths

    func testNormalizeDegrees() {
        XCTAssertEqual(RingRotation.normalizeDegrees(0), 0)
        XCTAssertEqual(RingRotation.normalizeDegrees(360), 0)
        XCTAssertEqual(RingRotation.normalizeDegrees(450), 90)
        XCTAssertEqual(RingRotation.normalizeDegrees(-90), 270)
        XCTAssertEqual(RingRotation.normalizeDegrees(-450), 270)
    }

    func testShortestAngularDistance() {
        XCTAssertEqual(RingRotation.shortestAngularDistanceDegrees(from: 350, to: 10), 20, accuracy: 1e-9)
        XCTAssertEqual(RingRotation.shortestAngularDistanceDegrees(from: 10, to: 350), -20, accuracy: 1e-9)
        XCTAssertEqual(RingRotation.shortestAngularDistanceDegrees(from: 0, to: 180), 180, accuracy: 1e-9)
        XCTAssertEqual(abs(RingRotation.shortestAngularDistanceDegrees(from: 90, to: 270)), 180, accuracy: 1e-9)
    }

    func testAlignmentTrueFalse() {
        XCTAssertTrue(RingRotation.isAligned(gap: 95, target: 90, tolerance: 22))
        XCTAssertTrue(RingRotation.isAligned(gap: 70, target: 90, tolerance: 22))
        XCTAssertFalse(RingRotation.isAligned(gap: 150, target: 90, tolerance: 22))
        // Wrapping across 0°.
        XCTAssertTrue(RingRotation.isAligned(gap: 358, target: 5, tolerance: 12))
        XCTAssertFalse(RingRotation.isAligned(gap: 340, target: 5, tolerance: 12))
    }

    func testRotateChangesGapAndSurvivesManyTurns() {
        var rot = RingRotation(initialGapAngleDegrees: 150, targetAngleDegrees: 90, toleranceDegrees: 22)
        XCTAssertFalse(rot.isAligned)
        rot.rotate(byDegrees: -60)
        XCTAssertEqual(rot.gapAngleDegrees, 90, accuracy: 1e-9)
        XCTAssertTrue(rot.isAligned)
        // Several whole turns must not change the alignment verdict.
        rot.rotate(byDegrees: 360 * 3)
        XCTAssertEqual(rot.gapAngleDegrees, 90, accuracy: 1e-9)
        XCTAssertTrue(rot.isAligned)
        rot.rotate(byDegrees: -360 * 5)
        XCTAssertEqual(rot.gapAngleDegrees, 90, accuracy: 1e-9)
        XCTAssertTrue(rot.isAligned)
    }

    func testSnapOnlyWhenWithinThreshold() {
        var rot = RingRotation(initialGapAngleDegrees: 96, targetAngleDegrees: 90, toleranceDegrees: 22)
        XCTAssertTrue(rot.snapToTargetIfWithin(7))
        XCTAssertEqual(rot.gapAngleDegrees, 90, accuracy: 1e-9)
        // Already on target → no further snap.
        XCTAssertFalse(rot.snapToTargetIfWithin(7))
        var far = RingRotation(initialGapAngleDegrees: 130, targetAngleDegrees: 90, toleranceDegrees: 22)
        XCTAssertFalse(far.snapToTargetIfWithin(7))
    }

    func testDirectionExitAngles() {
        XCTAssertEqual(Direction.e.exitAngleDegrees, 0, accuracy: 1e-9)
        XCTAssertEqual(Direction.n.exitAngleDegrees, 90, accuracy: 1e-9)
        XCTAssertEqual(Direction.w.exitAngleDegrees, 180, accuracy: 1e-9)
        XCTAssertEqual(Direction.s.exitAngleDegrees, 270, accuracy: 1e-9)
        XCTAssertEqual(Direction.ne.exitAngleDegrees, 45, accuracy: 1e-9)
        XCTAssertEqual(Direction.nw.exitAngleDegrees, 135, accuracy: 1e-9)
        XCTAssertEqual(Direction.sw.exitAngleDegrees, 225, accuracy: 1e-9)
        XCTAssertEqual(Direction.se.exitAngleDegrees, 315, accuracy: 1e-9)
    }

    // MARK: - Loading

    func testRingsLoadInitialGapAndStartMisaligned() throws {
        let pack = try TestBundleHelper.loadShippedPack()
        for level in pack.levels {
            for ring in level.rings {
                let rot = level.rotation(for: ring)
                XCTAssertFalse(
                    rot.isAligned,
                    "Level \(level.id) ring \(ring.id) must start misaligned (requires rotation)"
                )
            }
        }
    }

    func testToleranceBands() throws {
        let pack = try TestBundleHelper.loadShippedPack()
        for level in pack.levels {
            let expected = Level.defaultTolerance(forLevelID: level.id)
            XCTAssertEqual(level.alignmentToleranceDegrees, expected,
                           "Level \(level.id) tolerance band mismatch")
        }
    }

    // MARK: - Release rules

    private func level1() throws -> Level {
        let pack = try TestBundleHelper.loadShippedPack()
        return pack.levels.first { $0.id == 1 }!
    }

    func testUnalignedRingCannotBeRemoved() throws {
        let level = try level1()
        let s1 = level.ring("S1")!
        var state = GameState(level: level)
        // At its (misaligned) initial gap, a pull is refused.
        let outcome = state.attemptRelease(ringId: "S1", gapAngleDegrees: s1.initialGapAngleDegrees)
        guard case .notAligned = outcome else {
            return XCTFail("expected .notAligned, got \(outcome)")
        }
        XCTAssertFalse(state.clearedRingIds.contains("S1"))
        XCTAssertEqual(state.moveCount, 0, "a refused pull must not count as a move")
    }

    func testAlignedUnblockedRingReleases() throws {
        let level = try level1()
        let s1 = level.ring("S1")!
        var state = GameState(level: level)
        let outcome = state.attemptRelease(ringId: "S1", gapAngleDegrees: s1.targetExitAngleDegrees)
        XCTAssertEqual(outcome, .accepted)
        XCTAssertTrue(state.clearedRingIds.contains("S1"))
        XCTAssertEqual(state.moveCount, 1)
    }

    func testAlignedButBlockedRingStillCannotBeRemoved() throws {
        let level = try level1()
        let c1 = level.ring("C1")!   // requires S1
        var state = GameState(level: level)
        // Gap perfectly aligned, but S1 is still on the board.
        let outcome = state.attemptRelease(ringId: "C1", gapAngleDegrees: c1.targetExitAngleDegrees)
        guard case .blockedByPrerequisite(let missing) = outcome else {
            return XCTFail("expected .blockedByPrerequisite, got \(outcome)")
        }
        XCTAssertEqual(missing, ["S1"])
        XCTAssertFalse(state.clearedRingIds.contains("C1"))
        XCTAssertEqual(state.moveCount, 0)
    }

    func testRotationOnlyDoesNotCountAsMove() throws {
        // The engine only counts a move on an accepted release; rolling the gap is
        // pure view/rotation state and never touches GameState.moveCount.
        let level = try level1()
        var state = GameState(level: level)
        _ = state.attemptRelease(ringId: "S1", gapAngleDegrees: level.ring("S1")!.initialGapAngleDegrees)
        XCTAssertEqual(state.moveCount, 0)
    }

    func testAllLevelsCompleteWhenEachRingAlignedFirst() throws {
        let pack = try TestBundleHelper.loadShippedPack()
        for level in pack.levels {
            var state = GameState(level: level)
            for step in level.solution {
                guard let ring = level.ring(step.ringId) else {
                    XCTFail("Level \(level.id) missing ring \(step.ringId)"); continue
                }
                // Roll the gap onto the exit, then pull.
                let outcome = state.attemptRelease(
                    ringId: ring.id,
                    gapAngleDegrees: ring.targetExitAngleDegrees
                )
                XCTAssertEqual(outcome, .accepted,
                               "Level \(level.id) step \(ring.id) rejected: \(outcome)")
            }
            XCTAssertTrue(state.isComplete, "Level \(level.id) not complete after aligned solution")
            XCTAssertEqual(state.moveCount, level.solution.count)
        }
    }
}
