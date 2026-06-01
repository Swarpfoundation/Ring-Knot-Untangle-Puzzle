import XCTest
@testable import RingKnot

final class ProgressStoreTests: XCTestCase {

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suite = "RingKnotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (defaults, suite)
    }

    func testEmptyStoreReturnsInitialSnapshot() {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProgressStore(defaults: defaults, key: "k")
        let snap = store.load()
        XCTAssertEqual(snap.unlockedLevelID, 1)
        XCTAssertTrue(snap.records.isEmpty)
    }

    func testRoundTripPersistsRecords() {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProgressStore(defaults: defaults, key: "k")
        let snapshot = ProgressSnapshot(
            unlockedLevelID: 4,
            records: [
                1: LevelRecord(completed: true, bestMoveCount: 2),
                2: LevelRecord(completed: true, bestMoveCount: 5),
                3: LevelRecord(completed: true, bestMoveCount: 9)
            ]
        )
        store.save(snapshot)
        let reloaded = store.load()
        XCTAssertEqual(reloaded.unlockedLevelID, 4)
        XCTAssertEqual(reloaded.records.count, 3)
        XCTAssertEqual(reloaded.records[1]?.bestMoveCount, 2)
        XCTAssertEqual(reloaded.records[3]?.completed, true)
    }

    func testRecordCompletionUpdatesUnlockAndBest() {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProgressStore(defaults: defaults, key: "k")
        _ = store.record(completion: 1, moves: 8, totalLevels: 20)
        var snap = store.load()
        XCTAssertEqual(snap.unlockedLevelID, 2)
        XCTAssertEqual(snap.records[1]?.bestMoveCount, 8)
        _ = store.record(completion: 1, moves: 5, totalLevels: 20)
        snap = store.load()
        XCTAssertEqual(snap.records[1]?.bestMoveCount, 5, "best should improve")
        _ = store.record(completion: 1, moves: 12, totalLevels: 20)
        snap = store.load()
        XCTAssertEqual(snap.records[1]?.bestMoveCount, 5, "best should not regress")
    }

    func testRecordCompletionClampsToTotalLevels() {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProgressStore(defaults: defaults, key: "k")
        _ = store.record(completion: 20, moves: 18, totalLevels: 20)
        let snap = store.load()
        XCTAssertEqual(snap.unlockedLevelID, 20)
    }
}
