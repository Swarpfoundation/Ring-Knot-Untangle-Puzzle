import Foundation

public struct Cell: Hashable, Codable, Sendable, CustomStringConvertible {
    public let row: Int
    public let col: Int
    public let subSlot: Int

    public init(row: Int, col: Int, subSlot: Int = 0) {
        self.row = row
        self.col = col
        self.subSlot = subSlot
    }

    public var description: String {
        let rowChar = Character(UnicodeScalar(65 + row)!)
        let colNumber = col + 1
        let suffix: String
        switch subSlot {
        case 0: suffix = ""
        case 1: suffix = "a"
        case 2: suffix = "b"
        case 3: suffix = "c"
        default: suffix = ""
        }
        return "\(rowChar)\(colNumber)\(suffix)"
    }

    public static func parse(_ raw: String) -> Cell? {
        guard let first = raw.first, first.isLetter else { return nil }
        let rowChar = Character(first.uppercased())
        guard let ascii = rowChar.asciiValue, ascii >= 65, ascii <= 90 else { return nil }
        let row = Int(ascii) - 65
        let rest = raw.dropFirst()
        var digits = ""
        var suffix = ""
        for ch in rest {
            if ch.isNumber {
                digits.append(ch)
            } else if ch.isLetter {
                suffix.append(ch.lowercased())
            } else {
                return nil
            }
        }
        guard let colNumber = Int(digits), colNumber >= 1 else { return nil }
        let col = colNumber - 1
        let subSlot: Int
        switch suffix {
        case "": subSlot = 0
        case "a": subSlot = 1
        case "b": subSlot = 2
        case "c": subSlot = 3
        default: return nil
        }
        return Cell(row: row, col: col, subSlot: subSlot)
    }
}
