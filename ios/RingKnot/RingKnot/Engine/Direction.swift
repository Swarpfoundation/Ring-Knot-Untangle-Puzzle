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

    /// Unit vector in **scene space** (SpriteKit y-axis points up), where the JSON
    /// `dy` (positive = south/down) is flipped. So `N` points to `+y` (up the
    /// screen) and `S` to `-y`. Use this for any rendering, drag projection, or
    /// gap-alignment maths so "North" reads as up.
    public var sceneUnitVector: CGVector {
        let v = vector
        let mag = (v.dx == 0 || v.dy == 0) ? 1.0 : sqrt(2.0)
        return CGVector(dx: CGFloat(v.dx) / mag, dy: CGFloat(-v.dy) / mag)
    }

    /// Scene-space angle in radians (counter-clockwise from +x), matching
    /// `sceneUnitVector`. This is the angle an aligned ring's gap points toward.
    public var sceneRadians: CGFloat {
        let v = sceneUnitVector
        return atan2(v.dy, v.dx)
    }

    /// The gap angle, in degrees, a ring must reach for its opening to face this
    /// exit direction. Screen convention: East = 0°, North = 90°, West = 180°,
    /// South = 270° (counter-clockwise positive), normalized to `[0, 360)`.
    public var exitAngleDegrees: Double {
        let degrees = Double(sceneRadians) * 180.0 / .pi
        return RingRotation.normalizeDegrees(degrees)
    }

    public static func parse(_ raw: String) -> Direction? {
        Direction(rawValue: raw.uppercased())
    }
}
