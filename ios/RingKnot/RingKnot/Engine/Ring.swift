import Foundation

public enum RingKind: String, Codable, Hashable, Sendable {
    case silver
    case copper
}

/// The physical shape/role of a ring.
///
/// - `openRing`: the classic C-shaped ring with a visible gap. Rotatable and
///   (by default) removable — roll the gap to the exit, then pull it free.
/// - `closedAnchor`: a fully closed ring with no gap. It cannot be rolled or
///   released in normal play; it acts as a fixed anchor/obstacle that other
///   rings interlock with, and it stays on the board after the level is solved.
///
/// Backward compatibility: any ring loaded without an explicit body type
/// defaults to `openRing`, so older level packs keep working unchanged.
public enum RingBodyType: String, Codable, Hashable, Sendable {
    case openRing
    case closedAnchor
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
    /// Open C-ring vs. full closed anchor. Defaults to `.openRing`.
    public let bodyType: RingBodyType
    /// Whether this ring can be released by the player. Open rings default to
    /// `true`; closed anchors default to `false`. Level completion only counts
    /// removable rings, so non-removable anchors stay on the board.
    public let removable: Bool

    public init(
        id: String,
        kind: RingKind,
        cell: Cell,
        exitDirection: Direction,
        requires: [String],
        initialGapAngleDegrees: Double? = nil,
        bodyType: RingBodyType = .openRing,
        removable: Bool? = nil
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
        self.bodyType = bodyType
        // Open rings are removable unless told otherwise; closed anchors are
        // fixed unless a future level explicitly opts them in.
        self.removable = removable ?? (bodyType == .openRing)
    }

    /// A fully closed anchor ring — has no gap and is not rolled/released.
    public var isAnchor: Bool { bodyType == .closedAnchor }

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
