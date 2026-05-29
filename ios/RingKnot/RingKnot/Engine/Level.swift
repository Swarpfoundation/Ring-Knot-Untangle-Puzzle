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

    public func ring(_ id: String) -> Ring? {
        rings.first { $0.id == id }
    }
}

public struct LevelPack: Hashable, Sendable {
    public let game: String
    public let version: String
    public let levels: [Level]
}
