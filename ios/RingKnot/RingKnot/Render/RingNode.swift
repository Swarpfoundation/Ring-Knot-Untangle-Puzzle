import SpriteKit
import UIKit

final class RingNode: SKNode {
    let ring: Ring
    let cellSize: CGFloat
    let homePosition: CGPoint
    private let reduceMotion: Bool
    private let sprite: SKSpriteNode
    private let glow: SKShapeNode
    /// Separate ring used for the "gap aligned, ready to pull" state so it does
    /// not fight the selection / hint glow on `glow`.
    private let readyRing: SKShapeNode
    private(set) var isCleared: Bool = false

    /// Whether this is a fixed closed-anchor ring: full circle, no gap, no
    /// rotation, and never released by the player.
    let isAnchor: Bool
    /// Clips mounted on this ring (blocker/connector/bridge clamp bands).
    private let clips: [BlockerClip]
    /// Clips that roll with the ring (open rings) live here; the layer's
    /// zRotation tracks the ring's roll relative to its starting gap.
    private let rollingClipLayer = SKNode()
    /// Clips that stay put (closed anchors) live here.
    private let staticClipLayer = SKNode()
    private let initialGapRadians: CGFloat

    /// Live rotation state. The gap angle is rendered by rotating `sprite`
    /// (zRotation, counter-clockwise) — the texture itself is baked once with the
    /// gap at screen-east, so `zRotation == gapAngleRadians`.
    private(set) var rotation: RingRotation

    init(
        ring: Ring,
        rotation: RingRotation,
        cellSize: CGFloat,
        homePosition: CGPoint,
        reduceMotion: Bool,
        clips: [BlockerClip] = []
    ) {
        self.ring = ring
        self.rotation = rotation
        self.cellSize = cellSize
        self.homePosition = homePosition
        self.reduceMotion = reduceMotion
        self.isAnchor = ring.isAnchor
        self.clips = clips
        self.initialGapRadians = RingNode.radians(fromDegrees: ring.initialGapAngleDegrees)

        let diameter = cellSize * 0.88
        // Anchors are full closed rings (gap 0); open rings bake the gap at
        // screen-east (rotationRadians: 0) so the gap's on-screen angle is then
        // driven entirely by the sprite's zRotation.
        let texture = RingTextureFactory.texture(
            for: ring.kind,
            gapDegrees: ring.isAnchor ? 0 : 72,
            rotationRadians: 0,
            diameter: diameter
        )
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: diameter, height: diameter))
        sprite.zPosition = 1
        self.sprite = sprite

        let glow = SKShapeNode(circleOfRadius: diameter * 0.55)
        glow.lineWidth = 3
        glow.strokeColor = .clear
        glow.fillColor = .clear
        glow.zPosition = 0
        glow.alpha = 0
        self.glow = glow

        let readyRing = SKShapeNode(circleOfRadius: diameter * 0.60)
        readyRing.lineWidth = 4
        readyRing.strokeColor = RingPalette.readyGlow
        readyRing.fillColor = .clear
        readyRing.zPosition = 2
        readyRing.alpha = 0
        readyRing.blendMode = .add
        self.readyRing = readyRing

        super.init()

        addBacking(diameter: diameter)
        addChild(glow)
        addChild(sprite)
        addChild(readyRing)
        rollingClipLayer.zPosition = 4
        staticClipLayer.zPosition = 4
        addChild(staticClipLayer)
        addChild(rollingClipLayer)
        position = homePosition
        zPosition = CGFloat(ring.zIndex)
        applyVisualOffset()
        buildClips(diameter: diameter)
        if isAnchor {
            // Closed anchors never roll and have no "ready" state.
            sprite.zRotation = 0
        } else {
            sprite.zRotation = RingNode.radians(fromDegrees: rotation.gapAngleDegrees)
            if rotation.isAligned { showReady(true) }
        }
    }

    /// Build the clamp-band child nodes for this ring. Rolling clips (open rings)
    /// go in `rollingClipLayer` so they spin with the ring; static clips (anchors)
    /// stay in `staticClipLayer`. Phase 6B: contact-point placement, per-style
    /// silhouettes, over/under z-depth, and a soft contact shadow on the ring
    /// the clamp crosses.
    private func buildClips(diameter: CGFloat) {
        guard !clips.isEmpty else { return }
        for clip in clips {
            // Silhouette per clamp style (across-tube width × along-ring length).
            let (acrossF, alongF): (CGFloat, CGFloat)
            switch clip.clampStyle {
            case .shortBand:   (acrossF, alongF) = (0.22, 0.15)
            case .rivetedBand: (acrossF, alongF) = (0.24, 0.15)
            case .wideBand:    (acrossF, alongF) = (0.27, 0.17)
            case .bridgeBand:  (acrossF, alongF) = (0.30, 0.16)
            }
            let widthAcross = diameter * acrossF * CGFloat(clip.visualWidthScale)
            let lengthAlong = diameter * alongF

            // Contact-point placement.
            let angle = RingNode.radians(fromDegrees: clip.angleDegrees)
            let position: CGPoint
            switch clip.contactPointMode {
            case .explicit:
                if let off = clip.explicitPositionOffset {
                    position = CGPoint(x: CGFloat(off.x) * cellSize,
                                       y: CGFloat(off.y) * cellSize)
                } else {
                    position = CGPoint(x: cos(angle) * diameter * 0.385,
                                       y: sin(angle) * diameter * 0.385)
                }
            case .betweenCenters:
                // Push the clamp out to the contact rim between the two rings so
                // it sits where the tubes actually meet / bridges the gap.
                let r = diameter * (clip.clampStyle == .bridgeBand ? 0.54 : 0.50)
                position = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            case .ownerAngle:
                position = CGPoint(x: cos(angle) * diameter * 0.385,
                                   y: sin(angle) * diameter * 0.385)
            }

            let texture = RingTextureFactory.clipTexture(
                for: clip.material,
                owner: ring.kind,
                size: CGSize(width: widthAcross, height: lengthAlong),
                style: clip.clampStyle
            )
            let band = SKSpriteNode(texture: texture,
                                    size: CGSize(width: widthAcross, height: lengthAlong))
            band.position = position
            band.zRotation = angle
            band.zPosition = RingNode.clipZPosition(for: clip.depthRole)

            // Soft contact shadow cast onto the ring the clamp crosses.
            let shadow = SKShapeNode(ellipseOf: CGSize(width: widthAcross * 0.95,
                                                       height: lengthAlong * 1.15))
            shadow.fillColor = UIColor.black.withAlphaComponent(0.28)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: position.x, y: position.y - lengthAlong * 0.12)
            shadow.zRotation = angle
            shadow.zPosition = band.zPosition - 0.5

            let layer = (clip.rotatesWithOwner && !isAnchor) ? rollingClipLayer : staticClipLayer
            layer.addChild(shadow)
            layer.addChild(band)
        }
    }

    /// Relative z within the clip layer for each depth role. Combined with the
    /// scene's `ignoresSiblingOrder`, this lets blocker clamps read above the
    /// rings they hold while decorative connectors tuck in at mid-depth.
    private static func clipZPosition(for role: ClipDepthRole) -> CGFloat {
        switch role {
        case .over:      return 6
        case .bridge:    return 5
        case .connector: return 1
        case .under:     return -3
        }
    }

    required init?(coder aDecoder: NSCoder) { nil }

    private static func radians(fromDegrees degrees: Double) -> CGFloat {
        CGFloat(degrees * .pi / 180.0)
    }

    /// Backing behind the ring sprite: a heavier drop shadow for fixed anchors so
    /// they feel planted, and a warm sheen behind copper so the knot reads as the
    /// premium centre of the board. (Phase 6B.)
    private func addBacking(diameter: CGFloat) {
        if isAnchor {
            let shadow = SKShapeNode(circleOfRadius: diameter * 0.52)
            shadow.fillColor = UIColor.black.withAlphaComponent(0.45)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 0, y: -diameter * 0.05)
            shadow.zPosition = -2
            addChild(shadow)
        }
        if ring.kind == .copper {
            let sheen = SKShapeNode(circleOfRadius: diameter * 0.6)
            sheen.fillColor = UIColor(red: 1.0, green: 0.66, blue: 0.36, alpha: 0.18)
            sheen.strokeColor = .clear
            sheen.zPosition = -1
            sheen.blendMode = .add
            if !reduceMotion {
                sheen.run(SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.32, duration: 1.4),
                    SKAction.fadeAlpha(to: 0.16, duration: 1.4)
                ])))
            }
            addChild(sheen)
        }
    }

    private func applyVisualOffset() {
        guard ring.visualOffsetSlot > 0 else { return }
        let step = cellSize * 0.07
        let angle = CGFloat(ring.visualOffsetSlot - 1) * (CGFloat.pi / 3)
        let dx = cos(angle) * step
        let dy = sin(angle) * step
        sprite.position = CGPoint(x: dx, y: dy)
        glow.position = sprite.position
        readyRing.position = sprite.position
        rollingClipLayer.position = sprite.position
        staticClipLayer.position = sprite.position
    }

    // MARK: - Rotation

    var isAligned: Bool { rotation.isAligned }
    var gapAngleDegrees: Double { rotation.gapAngleDegrees }
    var signedDistanceToTargetDegrees: Double { rotation.signedDistanceToTargetDegrees }

    /// Roll the gap by an on-screen angular delta (radians, counter-clockwise).
    /// Applies a subtle magnetic snap when the gap comes within `snapDegrees` of
    /// the exit. Returns whether the ring *became* aligned and whether a snap fired.
    @discardableResult
    func rotateGap(byRadians delta: CGFloat, snapDegrees: Double = 6) -> (becameAligned: Bool, didSnap: Bool) {
        guard !isAnchor else { return (false, false) }
        let wasAligned = rotation.isAligned
        rotation.rotate(byDegrees: Double(delta) * 180.0 / .pi)
        let didSnap = rotation.snapToTargetIfWithin(snapDegrees)
        applyRotationToSprite(animated: didSnap)
        let nowAligned = rotation.isAligned
        refreshReady(animated: nowAligned != wasAligned)
        return (becameAligned: nowAligned && !wasAligned, didSnap: didSnap)
    }

    /// Roll straight to the exit alignment (used by the accessibility action and
    /// the DEBUG test bridge so alignment is reachable without a drag gesture).
    func alignGapToExit() {
        guard !isAnchor else { return }
        let wasAligned = rotation.isAligned
        rotation.setGap(angleDegrees: rotation.targetAngleDegrees)
        applyRotationToSprite(animated: true)
        refreshReady(animated: !wasAligned)
    }

    /// Set the gap to a deliberately misaligned angle (DEBUG bridge only).
    func setGapMisaligned() {
        guard !isAnchor else { return }
        rotation.setGap(angleDegrees: rotation.targetAngleDegrees + rotation.toleranceDegrees + 45)
        applyRotationToSprite(animated: true)
        refreshReady(animated: true)
    }

    private func applyRotationToSprite(animated: Bool) {
        let target = RingNode.radians(fromDegrees: rotation.gapAngleDegrees)
        // Rolling clips spin with the ring, tracking the roll since its start gap.
        let clipRoll = target - initialGapRadians
        sprite.removeAction(forKey: "spin")
        rollingClipLayer.removeAction(forKey: "spin")
        guard animated, !reduceMotion else {
            sprite.zRotation = target
            rollingClipLayer.zRotation = clipRoll
            return
        }
        let spin = SKAction.rotate(toAngle: target, duration: 0.12, shortestUnitArc: true)
        spin.timingMode = .easeOut
        sprite.run(spin, withKey: "spin")
        let clipSpin = SKAction.rotate(toAngle: clipRoll, duration: 0.12, shortestUnitArc: true)
        clipSpin.timingMode = .easeOut
        rollingClipLayer.run(clipSpin, withKey: "spin")
    }

    private func refreshReady(animated: Bool) {
        showReady(rotation.isAligned)
    }

    private func showReady(_ active: Bool) {
        readyRing.removeAction(forKey: "ready")
        guard active else {
            readyRing.alpha = 0
            return
        }
        if reduceMotion {
            readyRing.alpha = 0.9
            return
        }
        readyRing.alpha = 0.9
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.45, duration: 0.5),
            SKAction.fadeAlpha(to: 0.9, duration: 0.5)
        ]))
        readyRing.run(pulse, withKey: "ready")
    }

    // MARK: - Selection / hint glow

    func showSelection(_ active: Bool) {
        glow.strokeColor = active ? RingPalette.selectionGlow : .clear
        glow.alpha = active ? 1.0 : 0
    }

    /// Briefly flash this ring (and its blocking clamps) amber to show it is the
    /// thing still holding a ring the player just tried to pull. (Phase 6B.)
    func pulseAsBlocker(reduceMotion: Bool) {
        removeAction(forKey: "blocker")
        glow.strokeColor = RingPalette.hintGlow
        glow.alpha = 0.0
        let flashes = reduceMotion ? 1 : 2
        let seq = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.95, duration: 0.12),
            SKAction.fadeAlpha(to: 0.0, duration: 0.28)
        ])
        glow.run(SKAction.repeat(seq, count: flashes), withKey: "blocker")
        guard !reduceMotion else { return }
        let bump = SKAction.sequence([
            SKAction.scale(to: 1.06, duration: 0.10),
            SKAction.scale(to: 1.0, duration: 0.14)
        ])
        rollingClipLayer.run(bump, withKey: "blocker")
        staticClipLayer.run(bump, withKey: "blocker")
    }

    /// Calm "this is a fixed anchor" feedback for a tap on a closed anchor: a
    /// brief steely pulse on the ring, no error shockwave, no gap/ready cue.
    func showAnchorFeedback() {
        removeAction(forKey: "anchor")
        let steel = UIColor(white: 0.75, alpha: 0.9)
        glow.strokeColor = steel
        glow.alpha = 0.0
        if reduceMotion {
            glow.alpha = 0.9
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.5),
                SKAction.run { [weak self] in self?.glow.alpha = 0 }
            ]), withKey: "anchor")
            return
        }
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.9, duration: 0.10),
            SKAction.fadeAlpha(to: 0.0, duration: 0.35)
        ])
        glow.run(pulse, withKey: "anchor")
    }

    func showHint(reduceMotion: Bool) {
        removeAction(forKey: "hint")
        glow.strokeColor = RingPalette.hintGlow
        glow.alpha = 1.0
        if reduceMotion {
            run(SKAction.sequence([
                SKAction.wait(forDuration: 1.2),
                SKAction.run { [weak self] in self?.showSelection(false) }
            ]), withKey: "hint")
            return
        }
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 0.18),
            SKAction.scale(to: 1.0, duration: 0.18)
        ])
        run(SKAction.sequence([
            SKAction.repeat(pulse, count: 3),
            SKAction.run { [weak self] in self?.showSelection(false) }
        ]), withKey: "hint")
    }

    /// Persistent highlight used by the Level 1 tutorial. Stays lit until
    /// explicitly cleared. Static when Reduce Motion is on, gently pulsing otherwise.
    func setTutorialHighlight(_ active: Bool, reduceMotion: Bool) {
        removeAction(forKey: "hint")
        removeAction(forKey: "tutorial")
        guard active else {
            glow.alpha = 0
            glow.strokeColor = .clear
            setScale(1.0)
            return
        }
        glow.strokeColor = RingPalette.hintGlow
        glow.alpha = 1.0
        guard !reduceMotion else { return }
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.06, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ]))
        run(pulse, withKey: "tutorial")
    }

    // MARK: - Translation feedback / exit

    /// Slide the ring outward along its exit direction as the player pulls, with
    /// resistance. Only meaningful once the gap is aligned; the rotation centre is
    /// always `homePosition`, so this translation never affects angle maths.
    func pullAlong(exitVector: CGVector, distance: CGFloat) {
        // Let the ring travel a little under the release distance so the pull
        // reads ("about to come free") before it actually pops out.
        let clamped = max(0, min(distance, cellSize * 0.42))
        position = CGPoint(
            x: homePosition.x + exitVector.dx * clamped,
            y: homePosition.y + exitVector.dy * clamped
        )
    }

    func snapBack(reduceMotion: Bool, completion: @escaping () -> Void) {
        removeAction(forKey: "move")
        if reduceMotion {
            position = homePosition
            completion()
            return
        }
        let amplitude = cellSize * 0.04
        let shake = SKAction.sequence([
            SKAction.moveBy(x: amplitude, y: 0, duration: 0.04),
            SKAction.moveBy(x: -amplitude * 2, y: 0, duration: 0.06),
            SKAction.moveBy(x: amplitude * 2, y: 0, duration: 0.06),
            SKAction.moveBy(x: -amplitude, y: 0, duration: 0.04)
        ])
        let snap = SKAction.move(to: homePosition, duration: 0.18)
        snap.timingMode = .easeOut
        run(SKAction.sequence([snap, shake, SKAction.run(completion)]), withKey: "move")
    }

    /// Return the ring to home without a shake (used after a pure rotation that
    /// nudged the node, or a deliberate "rotate first" message).
    func settleHome(reduceMotion: Bool) {
        removeAction(forKey: "move")
        guard position != homePosition else { return }
        if reduceMotion {
            position = homePosition
            return
        }
        let snap = SKAction.move(to: homePosition, duration: 0.14)
        snap.timingMode = .easeOut
        run(snap, withKey: "move")
    }

    func performExit(reduceMotion: Bool, completion: @escaping () -> Void) {
        isCleared = true
        removeAction(forKey: "move")
        showReady(false)
        let v = ring.exitDirection.sceneUnitVector
        let dx = v.dx * cellSize * 1.6
        let dy = v.dy * cellSize * 1.6
        let target = CGPoint(x: homePosition.x + dx, y: homePosition.y + dy)
        let duration: TimeInterval = reduceMotion ? 0.12 : 0.24
        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: duration)
        let group = SKAction.group([move, fade])
        run(SKAction.sequence([group, SKAction.removeFromParent(), SKAction.run(completion)]), withKey: "move")
    }
}
