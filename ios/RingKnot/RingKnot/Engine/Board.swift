import Foundation

public struct Board: Codable, Hashable, Sendable {
    public let rows: Int
    public let cols: Int

    public init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }

    public func contains(_ cell: Cell) -> Bool {
        cell.row >= 0 && cell.row < rows && cell.col >= 0 && cell.col < cols
    }
}
