import Foundation

public struct LevelRecord: Codable, Hashable, Sendable {
    public var completed: Bool
    public var bestMoveCount: Int?

    public init(completed: Bool = false, bestMoveCount: Int? = nil) {
        self.completed = completed
        self.bestMoveCount = bestMoveCount
    }
}

public struct ProgressSnapshot: Codable, Hashable, Sendable {
    public var unlockedLevelID: Int
    public var records: [Int: LevelRecord]

    public init(unlockedLevelID: Int = 1, records: [Int: LevelRecord] = [:]) {
        self.unlockedLevelID = unlockedLevelID
        self.records = records
    }
}

public protocol ProgressStoring: AnyObject {
    func load() -> ProgressSnapshot
    func save(_ snapshot: ProgressSnapshot)
}

public final class ProgressStore: ProgressStoring {
    private let defaults: UserDefaults
    private let key: String
    public static let defaultKey = "com.swarpfoundation.ringknot.progress.v1"

    public init(defaults: UserDefaults = .standard, key: String = ProgressStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> ProgressSnapshot {
        guard let data = defaults.data(forKey: key) else { return ProgressSnapshot() }
        do {
            let decoder = JSONDecoder()
            let codable = try decoder.decode(CodableSnapshot.self, from: data)
            return codable.snapshot
        } catch {
            return ProgressSnapshot()
        }
    }

    public func save(_ snapshot: ProgressSnapshot) {
        let codable = CodableSnapshot(snapshot: snapshot)
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(codable)
            defaults.set(data, forKey: key)
        } catch {
            return
        }
    }

    public func record(completion levelID: Int, moves: Int, totalLevels: Int) -> ProgressSnapshot {
        var snap = load()
        var record = snap.records[levelID] ?? LevelRecord()
        record.completed = true
        if let prev = record.bestMoveCount {
            record.bestMoveCount = min(prev, moves)
        } else {
            record.bestMoveCount = moves
        }
        snap.records[levelID] = record
        snap.unlockedLevelID = min(max(snap.unlockedLevelID, levelID + 1), totalLevels)
        save(snap)
        return snap
    }

    public func reset() {
        defaults.removeObject(forKey: key)
    }
}

private struct CodableSnapshot: Codable {
    var unlockedLevelID: Int
    var records: [CodableEntry]

    init(snapshot: ProgressSnapshot) {
        self.unlockedLevelID = snapshot.unlockedLevelID
        self.records = snapshot.records
            .sorted { $0.key < $1.key }
            .map { CodableEntry(levelID: $0.key, record: $0.value) }
    }

    var snapshot: ProgressSnapshot {
        var dict: [Int: LevelRecord] = [:]
        for entry in records { dict[entry.levelID] = entry.record }
        return ProgressSnapshot(unlockedLevelID: unlockedLevelID, records: dict)
    }
}

private struct CodableEntry: Codable {
    var levelID: Int
    var record: LevelRecord
}
