import Foundation

public struct GameState: Sendable {
    public let level: Level
    public private(set) var clearedRingIds: Set<String>
    public private(set) var moveCount: Int
    public private(set) var startedAt: Date
    public private(set) var completedAt: Date?

    public init(level: Level, now: Date = Date()) {
        self.level = level
        self.clearedRingIds = []
        self.moveCount = 0
        self.startedAt = now
        self.completedAt = nil
    }

    public var isComplete: Bool {
        clearedRingIds.count == level.rings.count
    }

    public var validator: MoveValidator { MoveValidator(level: level) }

    public mutating func attempt(
        ringId: String,
        dragDirection: Direction,
        now: Date = Date()
    ) -> MoveOutcome {
        let outcome = validator.evaluate(
            ringId: ringId,
            dragDirection: dragDirection,
            clearedIds: clearedRingIds
        )
        switch outcome {
        case .accepted:
            clearedRingIds.insert(ringId)
            moveCount += 1
            if isComplete { completedAt = now }
        case .blockedByPrerequisite, .wrongDirection:
            moveCount += 1
        case .alreadyCleared, .unknownRing:
            break
        }
        return outcome
    }

    public mutating func reset(now: Date = Date()) {
        clearedRingIds.removeAll()
        moveCount = 0
        startedAt = now
        completedAt = nil
    }
}
