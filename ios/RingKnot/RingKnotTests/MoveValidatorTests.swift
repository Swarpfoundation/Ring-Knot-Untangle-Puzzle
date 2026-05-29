import XCTest
@testable import RingKnot

final class MoveValidatorTests: XCTestCase {

    private func level3() throws -> Level {
        let pack = try TestBundleHelper.loadShippedPack()
        return pack.levels.first { $0.id == 3 }!
    }

    func testBlockedRingCannotBeRemoved() throws {
        let level = try level3()
        let validator = MoveValidator(level: level)
        let outcome = validator.evaluate(ringId: "C1", dragDirection: .s, clearedIds: [])
        if case .blockedByPrerequisite(let missing) = outcome {
            XCTAssertEqual(Set(missing), Set(["S2", "S3"]))
        } else {
            XCTFail("expected blockedByPrerequisite")
        }
    }

    func testValidMoveAccepted() throws {
        let level = try level3()
        let validator = MoveValidator(level: level)
        let outcome = validator.evaluate(ringId: "S1", dragDirection: .n, clearedIds: [])
        XCTAssertEqual(outcome, .accepted)
    }

    func testWrongDirectionRejected() throws {
        let level = try level3()
        let validator = MoveValidator(level: level)
        let outcome = validator.evaluate(ringId: "S1", dragDirection: .s, clearedIds: [])
        if case .wrongDirection(let expected) = outcome {
            XCTAssertEqual(expected, .n)
        } else {
            XCTFail("expected wrongDirection")
        }
    }

    func testDependencyUnlocksAfterClear() throws {
        let level = try level3()
        let validator = MoveValidator(level: level)
        XCTAssertFalse(validator.isUnlocked(ringId: "S2", clearedIds: []))
        XCTAssertTrue(validator.isUnlocked(ringId: "S2", clearedIds: ["S1"]))
        XCTAssertFalse(validator.isUnlocked(ringId: "C1", clearedIds: ["S1", "S2"]))
        XCTAssertTrue(validator.isUnlocked(ringId: "C1", clearedIds: ["S1", "S2", "S3"]))
    }

    func testGameStateCompletesViaSolutionPath() throws {
        let level = try level3()
        var state = GameState(level: level)
        for step in level.solution {
            let outcome = state.attempt(ringId: step.ringId, dragDirection: step.direction)
            XCTAssertEqual(outcome, .accepted, "step \(step.ringId) rejected")
        }
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.moveCount, level.solution.count)
        XCTAssertNotNil(state.completedAt)
    }

    func testNextSuggestedRingHint() throws {
        let level = try level3()
        let validator = MoveValidator(level: level)
        XCTAssertEqual(validator.nextSuggestedRingId(clearedIds: []), "S1")
        XCTAssertEqual(validator.nextSuggestedRingId(clearedIds: ["S1"]), "S2")
    }
}
