import Foundation

/// Material a blocker clip is drawn with. `inherited` means "use the owner
/// ring's material" (silver or copper); the explicit cases force a look.
public enum ClipMaterial: String, Codable, Hashable, Sendable {
    case silver
    case copper
    case darkSteel
    case inherited
}

/// Role a clip plays on the board.
///
/// - `blocker`: the small clamp that visually holds a ring in place; it explains
///   why a dependent ring cannot leave until the owner ring is removed.
/// - `connector`: a decorative clamp band joining two rings, communicating the
///   tight interlocked grid in the reference art without gating a dependency.
/// - `bridge`: a clip spanning the copper knot to a neighbouring ring.
public enum ClipKind: String, Codable, Hashable, Sendable {
    case blocker
    case connector
    case bridge
}

/// A small metal clamp/blocker band attached to a ring tube. Clips are the
/// visual language of the puzzle: they show where one ring is physically caught
/// by another. They never change the rules on their own — the engine still gates
/// release on dependencies + gap alignment — but every dependency is expected to
/// have a matching clip/interlock so the board reads as physically caught.
public struct BlockerClip: Hashable, Sendable {
    public let id: String
    /// The ring this clip is mounted on.
    public let ownerRingId: String
    /// Angle (degrees, screen convention: E=0, N=90, CCW+) around the owner ring
    /// where the clamp sits — typically pointing at the ring it blocks.
    public let angleDegrees: Double
    public let material: ClipMaterial
    public let kind: ClipKind
    /// Rings this clip visually holds in place (its `requires` edges).
    public let blocksRingIds: [String]
    /// Relative width of the clamp band (1.0 = default).
    public let visualWidthScale: Double
    /// When true the clip rolls with its owner ring's rotation (open rings); when
    /// false it stays put (closed anchors).
    public let rotatesWithOwner: Bool

    public init(
        id: String,
        ownerRingId: String,
        angleDegrees: Double,
        material: ClipMaterial = .inherited,
        kind: ClipKind = .blocker,
        blocksRingIds: [String] = [],
        visualWidthScale: Double = 1.0,
        rotatesWithOwner: Bool = true
    ) {
        self.id = id
        self.ownerRingId = ownerRingId
        self.angleDegrees = angleDegrees
        self.material = material
        self.kind = kind
        self.blocksRingIds = blocksRingIds
        self.visualWidthScale = visualWidthScale
        self.rotatesWithOwner = rotatesWithOwner
    }
}

/// Metadata describing why one ring is blocked by another, tying a dependency to
/// the clip that visually explains it. Every `requires` edge in a shipped level
/// is expected to have at least one matching interlock (validated by the replay
/// validator) so the dependency is never abstract.
public struct Interlock: Hashable, Sendable {
    public let id: String
    /// The ring that must be removed first (the one carrying the clip).
    public let blockerRingId: String
    /// The ring held back until the blocker leaves.
    public let blockedRingId: String
    /// The clip that represents the contact point.
    public let blockerClipId: String
    /// Angle (degrees, screen convention) of the contact point on the blocker.
    public let contactAngleDegrees: Double
    public let description: String

    public init(
        id: String,
        blockerRingId: String,
        blockedRingId: String,
        blockerClipId: String,
        contactAngleDegrees: Double,
        description: String = ""
    ) {
        self.id = id
        self.blockerRingId = blockerRingId
        self.blockedRingId = blockedRingId
        self.blockerClipId = blockerClipId
        self.contactAngleDegrees = contactAngleDegrees
        self.description = description
    }
}
