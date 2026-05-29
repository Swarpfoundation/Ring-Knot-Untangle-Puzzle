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

    public init(
        id: String,
        kind: RingKind,
        cell: Cell,
        exitDirection: Direction,
        requires: [String]
    ) {
        self.id = id
        self.kind = kind
        self.cell = cell
        self.exitDirection = exitDirection
        self.requires = requires
        let baseZ = (kind == .copper) ? 100 : 0
        self.zIndex = baseZ + cell.subSlot
        self.visualOffsetSlot = cell.subSlot
    }
}
