import CoreGraphics
import Foundation

public enum Direction: String, CaseIterable, Codable, Hashable, Sendable {
    case n = "N"
    case ne = "NE"
    case e = "E"
    case se = "SE"
    case s = "S"
    case sw = "SW"
    case w = "W"
    case nw = "NW"

    public var vector: (dx: Int, dy: Int) {
        switch self {
        case .n:  return (0, -1)
        case .ne: return (1, -1)
        case .e:  return (1, 0)
        case .se: return (1, 1)
        case .s:  return (0, 1)
        case .sw: return (-1, 1)
        case .w:  return (-1, 0)
        case .nw: return (-1, -1)
        }
    }

    public var unitVector: CGVector {
        let v = vector
        let mag = (v.dx == 0 || v.dy == 0) ? 1.0 : sqrt(2.0)
        return CGVector(dx: CGFloat(v.dx) / mag, dy: CGFloat(v.dy) / mag)
    }

    public var radians: CGFloat {
        let v = unitVector
        return atan2(v.dy, v.dx)
    }

    public static func parse(_ raw: String) -> Direction? {
        Direction(rawValue: raw.uppercased())
    }
}
