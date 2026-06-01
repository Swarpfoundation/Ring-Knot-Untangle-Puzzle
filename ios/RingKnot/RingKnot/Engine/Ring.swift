import Foundation

public enum RingKind: String, Codable, Hashable, Sendable {
    case silver
    case copper
}

public struct Ring: Hashable, Sendable {
    public let id: String
    public let kind: RingKind
    public let cell: Cell
    public let exitDirection: Direction
    public let requires: [String]
    public let zIndex: Int
    public let visualOffsetSlot: Int
    /// Gap angle (degrees, screen convention) the ring starts at. Deliberately
    /// offset from the exit direction so the player must roll the ring to align
    /// its opening before it can be pulled out. Loaded from the shared JSON
    /// (`initialGapAngle`) or derived deterministically when absent.
    public let initialGapAngleDegrees: Double

    public init(
        id: String,
        kind: RingKind,
        cell: Cell,
        exitDirection: Direction,
        requires: [String],
        initialGapAngleDegrees: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.cell = cell
        self.exitDirection = exitDirection
        self.requires = requires
        let baseZ = (kind == .copper) ? 100 : 0
        self.zIndex = baseZ + cell.subSlot
        self.visualOffsetSlot = cell.subSlot
        self.initialGapAngleDegrees = initialGapAngleDegrees
            ?? Ring.derivedInitialGapAngle(id: id, exitDirection: exitDirection)
    }

    /// Where the gap must point for this ring to release.
    public var targetExitAngleDegrees: Double { exitDirection.exitAngleDegrees }

    /// Deterministic fallback initial gap angle when the JSON omits one: a stable
    /// per-id offset from the exit direction, large enough that no ring ever
    /// starts already aligned. Identical inputs always yield the same angle so
    /// the fallback is replayable across platforms.
    static func derivedInitialGapAngle(id: String, exitDirection: Direction) -> Double {
        // Hash the id into a deterministic offset band of 50°…130° either way.
        let seed = id.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
        let magnitude = 50 + (abs(seed) % 81)            // 50…130
        let sign = (abs(seed) / 81) % 2 == 0 ? 1.0 : -1.0
        return RingRotation.normalizeDegrees(
            exitDirection.exitAngleDegrees + sign * Double(magnitude)
        )
    }
}
