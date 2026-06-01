import Foundation

/// How a tube and a clip/band occlude one another at a crossing point.
/// - `clipOverTube`: the clamp band sits above the tube (a clamp on top).
/// - `tubeOverClip`: the ring's tube passes above the band (the band threads
///   under the tube here) — this is what the split-arc overlay draws.
/// - `clipUnderTube` / `tubeUnderClip`: inverse hints, used for `under` bands.
public enum OcclusionRole: String, Codable, Hashable, Sendable {
    case tubeOverClip
    case tubeUnderClip
    case clipOverTube
    case clipUnderTube
}

/// A computed crossing between a ring tube and a contact band. Crossing zones are
/// derived in memory from the level's contact clips (no JSON change); the renderer
/// turns `tubeOverClip` zones into short arc segments of the ring's tube drawn on
/// top of the band, simulating true over/under occlusion at the tube level.
public struct CrossingZone: Hashable, Sendable {
    public let crossingId: String
    /// The ring whose tube segment is involved at this crossing.
    public let ringId: String
    /// The other ring the band connects to.
    public let contactRingId: String
    /// The contact clip/band id.
    public let clipId: String
    /// Angle (degrees, screen convention) on `ringId` where the band crosses it.
    public let angleDegrees: Double
    /// Angular width of the arc segment to redraw at the crossing.
    public let arcWidthDegrees: Double
    public let occlusionRole: OcclusionRole

    public init(
        crossingId: String,
        ringId: String,
        contactRingId: String,
        clipId: String,
        angleDegrees: Double,
        arcWidthDegrees: Double,
        occlusionRole: OcclusionRole
    ) {
        self.crossingId = crossingId
        self.ringId = ringId
        self.contactRingId = contactRingId
        self.clipId = clipId
        self.angleDegrees = angleDegrees
        self.arcWidthDegrees = arcWidthDegrees
        self.occlusionRole = occlusionRole
    }
}

public extension Level {
    /// Drawn coverage of a ring's tube in degrees: a full circle for closed
    /// anchors, a full circle minus the gap for open rings. Used by the split
    /// renderer (and tests) to confirm arc overlays never change total coverage.
    static let openRingGapDegrees: Double = 72

    func tubeCoverageDegrees(for ring: Ring) -> Double {
        ring.isAnchor ? 360 : 360 - Level.openRingGapDegrees
    }

    /// Compute the crossing zones for this level from its contact bands. Pure and
    /// deterministic — safe to call off the render thread and in tests.
    ///
    /// Rules (mirror `docs/art/interlock-visual-style.md` → Split-tube model):
    /// - `over` clamp: the band sits over the contact tube (`clipOverTube`).
    /// - `bridge`: the contact ring's tube passes over the band (`tubeOverClip`).
    /// - `connector`: the owner (anchor) tube passes over the band.
    /// - `under`: the contact tube passes over the band.
    /// - Copper protection: any band touching a copper ring also redraws the
    ///   copper tube over the band, so the knot is never hidden by a silver clip.
    func crossingZones() -> [CrossingZone] {
        var zones: [CrossingZone] = []
        var seen = Set<String>()

        func add(_ ringId: String, _ contactId: String, _ clipId: String,
                 _ angle: Double, _ width: Double, _ role: OcclusionRole) {
            let id = "X_\(clipId)_\(ringId)_\(role.rawValue)"
            guard seen.insert(id).inserted else { return }
            zones.append(CrossingZone(
                crossingId: id, ringId: ringId, contactRingId: contactId,
                clipId: clipId, angleDegrees: angle, arcWidthDegrees: width,
                occlusionRole: role))
        }

        for clip in clips where clip.isContactBand {
            guard let contactId = clip.contactRingId else { continue }
            let ownerKind = ring(clip.ownerRingId)?.kind
            let contactKind = ring(contactId)?.kind
            let angle = clip.angleDegrees           // owner -> contact
            let backAngle = (angle + 180).truncatingRemainder(dividingBy: 360)

            switch clip.depthRole {
            case .over:
                add(contactId, clip.ownerRingId, clip.id, backAngle, 44, .clipOverTube)
            case .bridge:
                add(contactId, clip.ownerRingId, clip.id, backAngle, 48, .tubeOverClip)
            case .connector:
                add(clip.ownerRingId, contactId, clip.id, angle, 52, .tubeOverClip)
            case .under:
                add(contactId, clip.ownerRingId, clip.id, backAngle, 48, .tubeOverClip)
            }

            // Copper protection: keep the knot's tube on top of any band.
            if ownerKind == .copper {
                add(clip.ownerRingId, contactId, clip.id, angle, 50, .tubeOverClip)
            }
            if contactKind == .copper {
                add(contactId, clip.ownerRingId, clip.id, backAngle, 50, .tubeOverClip)
            }
        }
        return zones
    }
}
