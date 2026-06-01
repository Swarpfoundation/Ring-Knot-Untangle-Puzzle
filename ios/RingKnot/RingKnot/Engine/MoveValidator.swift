import Foundation

public enum MoveOutcome: Hashable, Sendable {
    case accepted
    case blockedByPrerequisite(missing: [String])
    case wrongDirection(expected: Direction)
    /// The ring's gap is not yet lined up with its exit direction — the player
    /// must roll it into alignment before it will release.
    case notAligned(expected: Direction)
    /// The ring is a fixed closed anchor; it cannot be selected for release.
    /// This is a calm "it's an anchor" state, not an error.
    case notRemovable
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
        if !ring.removable { return .notRemovable }
        let missing = ring.requires.filter { !clearedIds.contains($0) }
        if !missing.isEmpty {
            return .blockedByPrerequisite(missing: missing)
        }
        if dragDirection != ring.exitDirection {
            return .wrongDirection(expected: ring.exitDirection)
        }
        return .accepted
    }

    /// Rotation-aware release check. A ring releases only when its prerequisites
    /// are cleared **and** its gap is aligned with the exit direction. The
    /// prerequisite check comes first, so an aligned-but-blocked ring reports the
    /// blocker (the player cannot remove it regardless), while an unblocked ring
    /// whose gap is off reports `.notAligned` ("rotate first").
    public func evaluateRelease(
        ringId: String,
        gapAngleDegrees: Double,
        clearedIds: Set<String>
    ) -> MoveOutcome {
        guard let ring = level.ring(ringId) else { return .unknownRing }
        if clearedIds.contains(ring.id) { return .alreadyCleared }
        // Closed anchors have no gap and cannot be pulled out.
        if !ring.removable { return .notRemovable }
        let missing = ring.requires.filter { !clearedIds.contains($0) }
        if !missing.isEmpty {
            return .blockedByPrerequisite(missing: missing)
        }
        if !isAligned(ringId: ring.id, gapAngleDegrees: gapAngleDegrees) {
            return .notAligned(expected: ring.exitDirection)
        }
        return .accepted
    }

    /// Whether a ring's gap angle is within the level's tolerance of its exit.
    public func isAligned(ringId: String, gapAngleDegrees: Double) -> Bool {
        guard let ring = level.ring(ringId) else { return false }
        return RingRotation.isAligned(
            gap: gapAngleDegrees,
            target: ring.targetExitAngleDegrees,
            tolerance: level.alignmentToleranceDegrees
        )
    }

    public func isUnlocked(ringId: String, clearedIds: Set<String>) -> Bool {
        guard let ring = level.ring(ringId) else { return false }
        if clearedIds.contains(ring.id) { return false }
        // Non-removable anchors are never "the next ring" — they don't leave.
        if !ring.removable { return false }
        return ring.requires.allSatisfy { clearedIds.contains($0) }
    }

    /// The next ring a hint should point at — always a removable ring on the
    /// solution path; closed anchors are skipped entirely.
    public func nextSuggestedRingId(clearedIds: Set<String>) -> String? {
        for step in level.solution where !clearedIds.contains(step.ringId) {
            if isUnlocked(ringId: step.ringId, clearedIds: clearedIds) {
                return step.ringId
            }
        }
        return level.rings.first { ring in
            ring.removable
                && !clearedIds.contains(ring.id)
                && isUnlocked(ringId: ring.id, clearedIds: clearedIds)
        }?.id
    }
}
