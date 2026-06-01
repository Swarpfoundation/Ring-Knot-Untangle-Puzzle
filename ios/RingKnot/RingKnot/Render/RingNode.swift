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

    /// Live rotation state. The gap angle is rendered by rotating `sprite`
    /// (zRotation, counter-clockwise) — the texture itself is baked once with the
    /// gap at screen-east, so `zRotation == gapAngleRadians`.
    private(set) var rotation: RingRotation

    init(ring: Ring, rotation: RingRotation, cellSize: CGFloat, homePosition: CGPoint, reduceMotion: Bool) {
        self.ring = ring
        self.rotation = rotation
        self.cellSize = cellSize
        self.homePosition = homePosition
        self.reduceMotion = reduceMotion

        let diameter = cellSize * 0.88
        // Bake the gap at screen-east (rotationRadians: 0); the gap's on-screen
        // angle is then driven entirely by the sprite's zRotation.
        let texture = RingTextureFactory.texture(
            for: ring.kind,
            gapDegrees: 72,
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

        addChild(glow)
        addChild(sprite)
        addChild(readyRing)
        position = homePosition
        zPosition = CGFloat(ring.zIndex)
        applyVisualOffset()
        sprite.zRotation = RingNode.radians(fromDegrees: rotation.gapAngleDegrees)
        if rotation.isAligned { showReady(true) }
    }

    required init?(coder aDecoder: NSCoder) { nil }

    private static func radians(fromDegrees degrees: Double) -> CGFloat {
        CGFloat(degrees * .pi / 180.0)
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
        let wasAligned = rotation.isAligned
        rotation.setGap(angleDegrees: rotation.targetAngleDegrees)
        applyRotationToSprite(animated: true)
        refreshReady(animated: !wasAligned)
    }

    /// Set the gap to a deliberately misaligned angle (DEBUG bridge only).
    func setGapMisaligned() {
        rotation.setGap(angleDegrees: rotation.targetAngleDegrees + rotation.toleranceDegrees + 45)
        applyRotationToSprite(animated: true)
        refreshReady(animated: true)
    }

    private func applyRotationToSprite(animated: Bool) {
        let target = RingNode.radians(fromDegrees: rotation.gapAngleDegrees)
        sprite.removeAction(forKey: "spin")
        guard animated, !reduceMotion else {
            sprite.zRotation = target
            return
        }
        let spin = SKAction.rotate(toAngle: target, duration: 0.12, shortestUnitArc: true)
        spin.timingMode = .easeOut
        sprite.run(spin, withKey: "spin")
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
