import Foundation

public enum MoveOutcome: Hashable, Sendable {
    case accepted
    case blockedByPrerequisite(missing: [String])
    case wrongDirection(expected: Direction)
    case alreadyCleared
    case unknownRing
}

public struct MoveValidator: Sendable {
    public let level: Level

    public init(level: Level) {
        self.level = level
    }

    public func evaluate(
        ringId: String,
        dragDirection: Direction,
        clearedIds: Set<String>
    ) -> MoveOutcome {
        guard let ring = level.ring(ringId) else { return .unknownRing }
        if clearedIds.contains(ring.id) { return .alreadyCleared }
        let missing = ring.requires.filter { !clearedIds.contains($0) }
        if !missing.isEmpty {
            return .blockedByPrerequisite(missing: missing)
        }
        if dragDirection != ring.exitDirection {
            return .wrongDirection(expected: ring.exitDirection)
        }
        return .accepted
    }

    public func isUnlocked(ringId: String, clearedIds: Set<String>) -> Bool {
        guard let ring = level.ring(ringId) else { return false }
        if clearedIds.contains(ring.id) { return false }
        return ring.requires.allSatisfy { clearedIds.contains($0) }
    }

    public func nextSuggestedRingId(clearedIds: Set<String>) -> String? {
        for step in level.solution where !clearedIds.contains(step.ringId) {
            if isUnlocked(ringId: step.ringId, clearedIds: clearedIds) {
                return step.ringId
            }
        }
        return level.rings.first { ring in
            !clearedIds.contains(ring.id) && isUnlocked(ringId: ring.id, clearedIds: clearedIds)
        }?.id
    }
}
