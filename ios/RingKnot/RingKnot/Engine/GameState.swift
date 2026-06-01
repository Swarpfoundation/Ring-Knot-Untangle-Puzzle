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

    /// The level is complete once every *removable* ring has left the board.
    /// Non-removable closed anchors are ignored — they stay on the board after
    /// completion as fixed obstacles.
    public var isComplete: Bool {
        level.removableRings.allSatisfy { clearedRingIds.contains($0.id) }
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
        case .notAligned, .notRemovable, .alreadyCleared, .unknownRing:
            break
        }
        return outcome
    }

    /// Rotation-aware release. A move is only counted when the ring actually
    /// leaves the board — rolling the gap into place, or a failed pull because the
    /// gap is off or the ring is still blocked, does not increment the counter.
    @discardableResult
    public mutating func attemptRelease(
        ringId: String,
        gapAngleDegrees: Double,
        now: Date = Date()
    ) -> MoveOutcome {
        let outcome = validator.evaluateRelease(
            ringId: ringId,
            gapAngleDegrees: gapAngleDegrees,
            clearedIds: clearedRingIds
        )
        switch outcome {
        case .accepted:
            clearedRingIds.insert(ringId)
            moveCount += 1
            if isComplete { completedAt = now }
        case .blockedByPrerequisite, .notAligned, .notRemovable, .wrongDirection,
             .alreadyCleared, .unknownRing:
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
