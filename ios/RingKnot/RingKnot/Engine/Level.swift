import Foundation

public struct SolutionStep: Hashable, Sendable {
    public let ringId: String
    public let direction: Direction
}

public struct Level: Hashable, Sendable {
    public let id: Int
    public let name: String
    public let difficulty: Int
    public let board: Board
    public let rings: [Ring]
    public let solution: [SolutionStep]
    /// How precisely a ring's gap must line up with its exit before it releases.
    /// Wider tolerance early on keeps rotation forgiving; it tightens as levels
    /// progress. Loaded from the JSON (`alignmentToleranceDegrees`) or defaulted
    /// from the level id band.
    public let alignmentToleranceDegrees: Double
    /// Small metal clamp bands attached to rings — the visual language showing
    /// where rings are caught. See `BlockerClip`.
    public let clips: [BlockerClip]
    /// Dependency-to-clip metadata; each `requires` edge is expected to have one.
    public let interlocks: [Interlock]
    /// When true the level is allowed to gate dependencies without a visual
    /// interlock. Reserved as an escape hatch; the shipped pack does not use it.
    public let abstractOnly: Bool

    public init(
        id: Int,
        name: String,
        difficulty: Int,
        board: Board,
        rings: [Ring],
        solution: [SolutionStep],
        alignmentToleranceDegrees: Double? = nil,
        clips: [BlockerClip] = [],
        interlocks: [Interlock] = [],
        abstractOnly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.difficulty = difficulty
        self.board = board
        self.rings = rings
        self.solution = solution
        self.alignmentToleranceDegrees =
            alignmentToleranceDegrees ?? Level.defaultTolerance(forLevelID: id)
        self.clips = clips
        self.interlocks = interlocks
        self.abstractOnly = abstractOnly
    }

    public func ring(_ id: String) -> Ring? {
        rings.first { $0.id == id }
    }

    /// Rings the player must remove to finish the level (anchors excluded).
    public var removableRings: [Ring] { rings.filter { $0.removable } }

    /// Closed anchor rings — fixed obstacles that stay on the board.
    public var anchors: [Ring] { rings.filter { $0.isAnchor } }

    /// Clips mounted on a given ring.
    public func clips(forOwner ringID: String) -> [BlockerClip] {
        clips.filter { $0.ownerRingId == ringID }
    }

    /// Clips that visually hold a given ring (its `blocksRingIds` include it).
    /// Used by hints / blocked feedback to point at the right clamp.
    public func clipsBlocking(_ ringID: String) -> [BlockerClip] {
        clips.filter { $0.blocksRingIds.contains(ringID) }
    }

    /// Rotation state for a ring at the start of the level (gap misaligned).
    public func rotation(for ring: Ring) -> RingRotation {
        RingRotation(
            initialGapAngleDegrees: ring.initialGapAngleDegrees,
            targetAngleDegrees: ring.targetExitAngleDegrees,
            toleranceDegrees: alignmentToleranceDegrees
        )
    }

    /// Tolerance band: 1–5 → 22°, 6–10 → 18°, 11–15 → 15°, 16–20 → 12°.
    /// Smoothness and readability matter more than artificial precision, so the
    /// curve stays gentle; later levels are harder because of longer dependency
    /// chains, not punishing alignment windows.
    public static func defaultTolerance(forLevelID id: Int) -> Double {
        switch id {
        case ..<6:   return 22
        case ..<11:  return 18
        case ..<16:  return 15
        default:     return 12
        }
    }
}

public struct LevelPack: Hashable, Sendable {
    public let game: String
    public let version: String
    public let levels: [Level]
}
