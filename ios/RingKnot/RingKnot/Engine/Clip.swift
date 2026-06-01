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

/// Over/under layering role used by the renderer (Phase 6B). A clip that holds a
/// ring should sit `over` (above) the ring it blocks; decorative joins sit at
/// `connector`/`bridge` mid-depth; `under` tucks a band beneath a neighbour.
public enum ClipDepthRole: String, Codable, Hashable, Sendable {
    case over
    case under
    case bridge
    case connector

    /// Sensible default for a clip kind when the JSON omits an explicit role.
    static func defaultFor(kind: ClipKind) -> ClipDepthRole {
        switch kind {
        case .blocker:   return .over
        case .connector: return .connector
        case .bridge:    return .bridge
        }
    }
}

/// How the renderer resolves a clip's on-board position.
/// - `ownerAngle`: legacy — place at the owner ring's tube along `angleDegrees`.
/// - `betweenCenters`: push the clamp out to the contact rim between the owner
///   and `contactRingId`, so it sits where the two tubes actually meet.
/// - `explicit`: use `explicitPositionOffset` from the owner centre.
public enum ClipContactPointMode: String, Codable, Hashable, Sendable {
    case ownerAngle
    case betweenCenters
    case explicit
}

/// Coarse depth band for the renderer.
public enum ClipVisualLayer: String, Codable, Hashable, Sendable {
    case foreground
    case midground
    case background
}

/// Silhouette of the clamp band.
public enum ClampStyle: String, Codable, Hashable, Sendable {
    case shortBand
    case wideBand
    case bridgeBand
    case rivetedBand
}

/// A simple 2-D offset (in cell units) used for explicit clip placement.
public struct ClipOffset: Hashable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
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

    // MARK: Phase 6B — interlock geometry / layering (all backward compatible)

    /// Over/under layering role. Defaults from `kind` when absent.
    public let depthRole: ClipDepthRole
    /// The ring this clip makes contact with (the blocked/joined neighbour).
    public let contactRingId: String?
    /// How the renderer resolves position.
    public let contactPointMode: ClipContactPointMode
    /// Offset (cell units) used when `contactPointMode == .explicit`.
    public let explicitPositionOffset: ClipOffset?
    /// Coarse depth band.
    public let visualLayer: ClipVisualLayer
    /// Clamp silhouette.
    public let clampStyle: ClampStyle
    /// Whether the clamp visually crosses the blocked ring's exit path.
    public let blocksExitDirection: Bool

    public init(
        id: String,
        ownerRingId: String,
        angleDegrees: Double,
        material: ClipMaterial = .inherited,
        kind: ClipKind = .blocker,
        blocksRingIds: [String] = [],
        visualWidthScale: Double = 1.0,
        rotatesWithOwner: Bool = true,
        depthRole: ClipDepthRole? = nil,
        contactRingId: String? = nil,
        contactPointMode: ClipContactPointMode = .ownerAngle,
        explicitPositionOffset: ClipOffset? = nil,
        visualLayer: ClipVisualLayer? = nil,
        clampStyle: ClampStyle? = nil,
        blocksExitDirection: Bool = false
    ) {
        self.id = id
        self.ownerRingId = ownerRingId
        self.angleDegrees = angleDegrees
        self.material = material
        self.kind = kind
        self.blocksRingIds = blocksRingIds
        self.visualWidthScale = visualWidthScale
        self.rotatesWithOwner = rotatesWithOwner
        self.depthRole = depthRole ?? ClipDepthRole.defaultFor(kind: kind)
        self.contactRingId = contactRingId
        self.contactPointMode = contactPointMode
        self.explicitPositionOffset = explicitPositionOffset
        self.visualLayer = visualLayer ?? (kind == .blocker ? .foreground : .midground)
        self.clampStyle = clampStyle ?? (kind == .bridge ? .bridgeBand : .shortBand)
        self.blocksExitDirection = blocksExitDirection
    }

    /// A clip is rendered as a neighbour-aware *contact band* (scene-level, fixed
    /// at the true contact point between owner and contact ring, with genuine
    /// over/under occlusion) when it names a contact ring or asks for a non-owner
    /// placement. Otherwise it is a legacy owner-attached band that rolls with the
    /// open ring. (Phase 6C.)
    public var isContactBand: Bool {
        contactRingId != nil || contactPointMode != .ownerAngle
    }
}

/// How a dependency contact is presented visually (Phase 6B).
/// `decorativeConnector` means the interlock is *not* enough to explain a
/// dependency on its own — the replay validator requires a non-decorative mode
/// for every shipped `requires` edge.
public enum InterlockVisualContactMode: String, Codable, Hashable, Sendable {
    case clipBlocksGap
    case ringPassesUnderAnchor
    case ringHeldByBridge
    case decorativeConnector

    /// Whether this mode actually explains a dependency (non-decorative).
    public var explainsDependency: Bool { self != .decorativeConnector }
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

    // MARK: Phase 6B (backward compatible)

    /// How the contact reads visually. Defaults to `.clipBlocksGap`.
    public let visualContactMode: InterlockVisualContactMode
    /// How far the blocked ring's gap must clear the clip before it releases
    /// (purely descriptive metadata; the engine still uses the level tolerance).
    public let requiredGapClearanceAngleDegrees: Double?
    /// Short human-readable note about the contact.
    public let contactDescription: String

    public init(
        id: String,
        blockerRingId: String,
        blockedRingId: String,
        blockerClipId: String,
        contactAngleDegrees: Double,
        description: String = "",
        visualContactMode: InterlockVisualContactMode = .clipBlocksGap,
        requiredGapClearanceAngleDegrees: Double? = nil,
        contactDescription: String = ""
    ) {
        self.id = id
        self.blockerRingId = blockerRingId
        self.blockedRingId = blockedRingId
        self.blockerClipId = blockerClipId
        self.contactAngleDegrees = contactAngleDegrees
        self.description = description
        self.visualContactMode = visualContactMode
        self.requiredGapClearanceAngleDegrees = requiredGapClearanceAngleDegrees
        self.contactDescription = contactDescription
    }
}
