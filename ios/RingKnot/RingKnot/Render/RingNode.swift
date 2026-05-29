import SpriteKit
import UIKit

final class RingNode: SKNode {
    let ring: Ring
    let cellSize: CGFloat
    let homePosition: CGPoint
    private let sprite: SKSpriteNode
    private let glow: SKShapeNode
    private(set) var isCleared: Bool = false

    init(ring: Ring, cellSize: CGFloat, homePosition: CGPoint, reduceMotion: Bool) {
        self.ring = ring
        self.cellSize = cellSize
        self.homePosition = homePosition

        let diameter = cellSize * 0.88
        let texture = RingTextureFactory.texture(
            for: ring.kind,
            gapDegrees: 72,
            rotationRadians: ring.exitDirection.radians,
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

        super.init()

        addChild(glow)
        addChild(sprite)
        position = homePosition
        zPosition = CGFloat(ring.zIndex)
        applyVisualOffset()
        _ = reduceMotion
    }

    required init?(coder aDecoder: NSCoder) { nil }

    private func applyVisualOffset() {
        guard ring.visualOffsetSlot > 0 else { return }
        let step = cellSize * 0.07
        let angle = CGFloat(ring.visualOffsetSlot - 1) * (CGFloat.pi / 3)
        let dx = cos(angle) * step
        let dy = sin(angle) * step
        sprite.position = CGPoint(x: dx, y: dy)
    }

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

    func resistanceDrag(toLocal point: CGPoint, exitVector: CGVector) {
        let projection = point.x * exitVector.dx + point.y * exitVector.dy
        let clampedAlong = max(min(projection, cellSize * 0.45), -cellSize * 0.1)
        let along = CGPoint(
            x: exitVector.dx * clampedAlong,
            y: exitVector.dy * clampedAlong
        )
        position = CGPoint(x: homePosition.x + along.x, y: homePosition.y + along.y)
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

    func performExit(reduceMotion: Bool, completion: @escaping () -> Void) {
        isCleared = true
        removeAction(forKey: "move")
        let v = ring.exitDirection.unitVector
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
