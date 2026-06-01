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

    public init(
        id: Int,
        name: String,
        difficulty: Int,
        board: Board,
        rings: [Ring],
        solution: [SolutionStep],
        alignmentToleranceDegrees: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.difficulty = difficulty
        self.board = board
        self.rings = rings
        self.solution = solution
        self.alignmentToleranceDegrees =
            alignmentToleranceDegrees ?? Level.defaultTolerance(forLevelID: id)
    }

    public func ring(_ id: String) -> Ring? {
        rings.first { $0.id == id }
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
