import XCTest
@testable import RingKnot

/// Phase 6D — split-tube crossing zones + occlusion rules (pure-model tests).
final class SplitTubeTests: XCTestCase {

    private func shipped() throws -> LevelPack {
        try TestBundleHelper.loadShippedPack()
    }

    private func level(_ id: Int) throws -> Level {
        try shipped().levels.first { $0.id == id }!
    }

    // MARK: - Crossing-zone generation

    func testCrossingZonesGeneratedFromContactBands() throws {
        for level in try shipped().levels {
            let zones = level.crossingZones()
            let ringIDs = Set(level.rings.map(\.id))
            let clipIDs = Set(level.clips.map(\.id))
            XCTAssertFalse(zones.isEmpty, "Level \(level.id) produced no crossing zones")
            for z in zones {
                XCTAssertTrue(ringIDs.contains(z.ringId))
                XCTAssertTrue(ringIDs.contains(z.contactRingId))
                XCTAssertTrue(clipIDs.contains(z.clipId))
                XCTAssertNotEqual(z.ringId, z.contactRingId)
                XCTAssertGreaterThan(z.arcWidthDegrees, 0)
                XCTAssertTrue(z.angleDegrees >= 0 && z.angleDegrees < 360)
            }
            // Unique crossing ids.
            XCTAssertEqual(Set(zones.map(\.crossingId)).count, zones.count)
        }
    }

    // MARK: - Coverage preserved (split overlays never change base coverage)

    func testTubeCoveragePreserved() throws {
        let level = try level(1)
        for ring in level.rings {
            let coverage = level.tubeCoverageDegrees(for: ring)
            if ring.isAnchor {
                XCTAssertEqual(coverage, 360, "anchor \(ring.id) should be a full circle")
            } else {
                XCTAssertEqual(coverage, 360 - Level.openRingGapDegrees,
                               "open ring \(ring.id) coverage should be 360 minus the gap")
            }
        }
    }

    // MARK: - bridge depth rule

    func testBridgeProducesTubeOverClip() throws {
        // A bridge band's crossing makes the contact tube pass over the band.
        for level in try shipped().levels {
            for clip in level.clips where clip.depthRole == .bridge && clip.isContactBand {
                let zones = level.crossingZones().filter { $0.clipId == clip.id }
                XCTAssertTrue(zones.contains { $0.occlusionRole == .tubeOverClip },
                    "Level \(level.id) bridge clip \(clip.id) has no tubeOverClip crossing")
            }
        }
    }

    func testOverClampProducesClipOverTube() throws {
        let level = try level(1)
        // The Level 1 blocker (depthRole over) reads as the clamp over the tube.
        let overClips = level.clips.filter { $0.depthRole == .over && $0.isContactBand }
        XCTAssertFalse(overClips.isEmpty)
        for clip in overClips {
            let zones = level.crossingZones().filter { $0.clipId == clip.id }
            XCTAssertTrue(zones.contains { $0.occlusionRole == .clipOverTube })
        }
    }

    // MARK: - Copper protection

    func testCopperKnotProtectedFromSilverBands() throws {
        // Any band touching a copper ring redraws the copper tube over the band,
        // so the knot is never hidden by a silver clip.
        for level in try shipped().levels {
            let copperIDs = Set(level.rings.filter { $0.kind == .copper }.map(\.id))
            let zones = level.crossingZones()
            for clip in level.clips where clip.isContactBand {
                guard let contact = clip.contactRingId else { continue }
                let touchesCopper = copperIDs.contains(clip.ownerRingId) || copperIDs.contains(contact)
                guard touchesCopper else { continue }
                let copperRing = copperIDs.contains(clip.ownerRingId) ? clip.ownerRingId : contact
                let protectedByOverArc = zones.contains {
                    $0.clipId == clip.id && $0.ringId == copperRing
                        && $0.occlusionRole == .tubeOverClip
                }
                XCTAssertTrue(protectedByOverArc,
                    "Level \(level.id) clip \(clip.id) does not keep copper \(copperRing) on top")
            }
        }
    }

    // MARK: - Level content

    func testLevel1HasAtLeastOneCrossingZone() throws {
        XCTAssertGreaterThanOrEqual(try level(1).crossingZones().count, 1)
    }

    func testLevel20HasMultipleCrossingZones() throws {
        XCTAssertGreaterThanOrEqual(try level(20).crossingZones().count, 4)
    }
}
