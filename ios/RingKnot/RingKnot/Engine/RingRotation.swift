import Foundation

/// Pure-Swift rotation maths for the rotatable-ring mechanic. A ring is an open
/// metal circle with a single gap; the player rolls it until the gap points at
/// the ring's exit direction, then pulls it out through that gap.
///
/// Angles are degrees in screen convention (East = 0°, North = 90°,
/// counter-clockwise positive). All comparisons go through
/// `shortestAngularDistanceDegrees` so a gap can be rotated through any number of
/// whole turns without numerical drift changing whether it reads as aligned.
public struct RingRotation: Hashable, Sendable {
    /// Where the gap must point for the ring to release (the exit direction).
    public let targetAngleDegrees: Double
    /// How close (in degrees) the gap must be to the target to count as aligned.
    public let toleranceDegrees: Double
    /// Current gap angle, always normalized to `[0, 360)`.
    public private(set) var gapAngleDegrees: Double

    public init(
        initialGapAngleDegrees: Double,
        targetAngleDegrees: Double,
        toleranceDegrees: Double
    ) {
        self.targetAngleDegrees = RingRotation.normalizeDegrees(targetAngleDegrees)
        self.toleranceDegrees = toleranceDegrees
        self.gapAngleDegrees = RingRotation.normalizeDegrees(initialGapAngleDegrees)
    }

    /// Signed shortest distance from the current gap to the target, in
    /// `(-180, 180]`. Positive means the gap is counter-clockwise of the target.
    public var signedDistanceToTargetDegrees: Double {
        RingRotation.shortestAngularDistanceDegrees(from: gapAngleDegrees, to: targetAngleDegrees)
    }

    /// True when the gap is within tolerance of the exit direction.
    public var isAligned: Bool {
        abs(signedDistanceToTargetDegrees) <= toleranceDegrees
    }

    /// Roll the gap by a delta (degrees). Multiple full turns are fine — the
    /// stored angle stays normalized so alignment never drifts.
    public mutating func rotate(byDegrees delta: Double) {
        gapAngleDegrees = RingRotation.normalizeDegrees(gapAngleDegrees + delta)
    }

    /// Set the gap to an absolute angle (degrees), normalized.
    public mutating func setGap(angleDegrees: Double) {
        gapAngleDegrees = RingRotation.normalizeDegrees(angleDegrees)
    }

    /// Snap the gap exactly onto the target if it is already within `snapDegrees`
    /// of it. Returns true when a snap happened (and the ring was not already
    /// sitting exactly on target), so callers can fire a subtle haptic / glow.
    @discardableResult
    public mutating func snapToTargetIfWithin(_ snapDegrees: Double) -> Bool {
        let distance = signedDistanceToTargetDegrees
        guard abs(distance) <= snapDegrees, distance != 0 else { return false }
        gapAngleDegrees = targetAngleDegrees
        return true
    }

    // MARK: - Angle maths (pure, reusable)

    /// Normalize any angle in degrees into `[0, 360)`.
    public static func normalizeDegrees(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    /// Shortest signed angular distance `from -> to`, in `(-180, 180]`.
    public static func shortestAngularDistanceDegrees(from: Double, to: Double) -> Double {
        var delta = normalizeDegrees(to) - normalizeDegrees(from)
        if delta > 180 { delta -= 360 }
        if delta <= -180 { delta += 360 }
        return delta
    }

    /// Whether `gap` is within `tolerance` of `target` (order-independent).
    public static func isAligned(gap: Double, target: Double, tolerance: Double) -> Bool {
        abs(shortestAngularDistanceDegrees(from: gap, to: target)) <= tolerance
    }
}
