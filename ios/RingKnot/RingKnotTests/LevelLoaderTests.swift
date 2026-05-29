import XCTest
@testable import RingKnot

final class LevelLoaderTests: XCTestCase {
    func testJSONLoadsAllTwentyLevels() throws {
        let pack = try TestBundleHelper.loadShippedPack()
        XCTAssertEqual(pack.levels.count, 20)
        XCTAssertEqual(pack.levels.map(\.id).sorted(), Array(1...20))
    }

    func testEveryShippedLevelHasCopperAndUniqueIDs() throws {
        let pack = try TestBundleHelper.loadShippedPack()
        for level in pack.levels {
            XCTAssertTrue(level.rings.contains(where: { $0.kind == .copper }), "Level \(level.id) missing copper")
            let ids = level.rings.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "Level \(level.id) duplicate ring IDs")
        }
    }

    func testDuplicateLevelIDIsRejected() {
        let payload: [String: Any] = [
            "game": "Ring Unlock",
            "version": "1.0.0",
            "levels": [
                makeMinimalLevelDict(id: 1),
                makeMinimalLevelDict(id: 1)
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        XCTAssertThrowsError(try LevelLoader.decode(data)) { error in
            XCTAssertEqual(error as? LevelLoaderError, .duplicateLevelID(1))
        }
    }

    func testDuplicateRingIDIsRejected() {
        var level = makeMinimalLevelDict(id: 1)
        level["pieces"] = [
            ringDict("S1", "silver", "B3", "N"),
            ringDict("S1", "silver", "B4", "E"),
            ringDict("C1", "copper", "C3", "S", requires: ["S1"])
        ]
        let payload: [String: Any] = [
            "game": "x", "version": "1.0.0", "levels": [level]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        XCTAssertThrowsError(try LevelLoader.decode(data)) { error in
            if case .duplicateRingID(let levelID, let ringID) = (error as? LevelLoaderError) {
                XCTAssertEqual(levelID, 1)
                XCTAssertEqual(ringID, "S1")
            } else {
                XCTFail("expected duplicateRingID")
            }
        }
    }

    func testMissingDependencyRejected() {
        var level = makeMinimalLevelDict(id: 1)
        level["pieces"] = [
            ringDict("S1", "silver", "B3", "N"),
            ringDict("C1", "copper", "C3", "S", requires: ["GHOST"])
        ]
        let payload: [String: Any] = ["game": "x", "version": "1.0.0", "levels": [level]]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        XCTAssertThrowsError(try LevelLoader.decode(data)) { error in
            if case .unknownDependency(_, let ringID, let missing) = (error as? LevelLoaderError) {
                XCTAssertEqual(ringID, "C1")
                XCTAssertEqual(missing, "GHOST")
            } else {
                XCTFail("expected unknownDependency, got \(String(describing: error))")
            }
        }
    }

    func testInvalidDirectionRejected() {
        var level = makeMinimalLevelDict(id: 1)
        level["pieces"] = [
            ringDict("S1", "silver", "B3", "Z"),
            ringDict("C1", "copper", "C3", "S", requires: ["S1"])
        ]
        let payload: [String: Any] = ["game": "x", "version": "1.0.0", "levels": [level]]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        XCTAssertThrowsError(try LevelLoader.decode(data)) { error in
            if case .unknownDirection(_, _, let raw) = (error as? LevelLoaderError) {
                XCTAssertEqual(raw, "Z")
            } else {
                XCTFail("expected unknownDirection")
            }
        }
    }

    func testMissingCopperRejected() {
        var level = makeMinimalLevelDict(id: 1)
        level["pieces"] = [
            ringDict("S1", "silver", "B3", "N"),
            ringDict("S2", "silver", "B4", "E")
        ]
        level["solution"] = [ ["id": "S1", "drag": "N"], ["id": "S2", "drag": "E"] ]
        let payload: [String: Any] = ["game": "x", "version": "1.0.0", "levels": [level]]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        XCTAssertThrowsError(try LevelLoader.decode(data)) { error in
            XCTAssertEqual(error as? LevelLoaderError, .missingCopper(levelID: 1))
        }
    }

    func testCycleRejected() {
        var level = makeMinimalLevelDict(id: 1)
        level["pieces"] = [
            ringDict("S1", "silver", "B3", "N", requires: ["S2"]),
            ringDict("S2", "silver", "B4", "E", requires: ["S1"]),
            ringDict("C1", "copper", "C3", "S", requires: ["S1"])
        ]
        let payload: [String: Any] = ["game": "x", "version": "1.0.0", "levels": [level]]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        XCTAssertThrowsError(try LevelLoader.decode(data)) { error in
            if case .dependencyCycle = (error as? LevelLoaderError) {} else {
                XCTFail("expected dependencyCycle, got \(String(describing: error))")
            }
        }
    }

    private func makeMinimalLevelDict(id: Int) -> [String: Any] {
        return [
            "id": id,
            "name": "Test",
            "difficulty": 1,
            "board": ["rows": 5, "cols": 5],
            "pieces": [
                ringDict("S1", "silver", "B3", "N"),
                ringDict("C1", "copper", "C3", "S", requires: ["S1"])
            ],
            "solution": [
                ["id": "S1", "drag": "N"],
                ["id": "C1", "drag": "S"]
            ]
        ]
    }

    private func ringDict(
        _ id: String,
        _ kind: String,
        _ cell: String,
        _ direction: String,
        requires: [String] = []
    ) -> [String: Any] {
        return [
            "id": id,
            "kind": kind,
            "cell": cell,
            "exitDirection": direction,
            "requires": requires
        ]
    }
}
