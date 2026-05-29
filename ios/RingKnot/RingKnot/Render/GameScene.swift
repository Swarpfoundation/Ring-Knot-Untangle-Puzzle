import SpriteKit
import UIKit

protocol GameSceneDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didChangeMoves moves: Int)
    func gameScene(_ scene: GameScene, didCompleteLevel level: Level, moves: Int)
    func gameSceneRequestsHaptic(_ scene: GameScene, kind: HapticKind)
}

enum HapticKind {
    case select
    case success
    case warning
    case completion
}

final class GameScene: SKScene {
    private let level: Level
    private var state: GameState
    private let reduceMotion: Bool

    private var ringNodes: [String: RingNode] = [:]
    private var selectedNode: RingNode?
    private var dragStartLocation: CGPoint = .zero

    private var cellSize: CGFloat = 0
    private var boardOrigin: CGPoint = .zero

    private var fxLayer: SKNode = SKNode()
    private var hintArrowNode: SKSpriteNode?
    private var selectionGlowNode: SKSpriteNode?

    weak var gameDelegate: GameSceneDelegate?

    init(level: Level, reduceMotion: Bool) {
        self.level = level
        self.state = GameState(level: level)
        self.reduceMotion = reduceMotion
        super.init(size: .zero)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        view.allowsTransparency = true
        rebuildScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if size.width > 0, size.height > 0, !ringNodes.isEmpty {
            rebuildScene()
        }
    }

    func restart() {
        state.reset()
        gameDelegate?.gameScene(self, didChangeMoves: state.moveCount)
        rebuildScene()
    }

    func highlightHint() {
        guard let id = state.validator.nextSuggestedRingId(clearedIds: state.clearedRingIds),
              let node = ringNodes[id] else { return }
        node.showHint(reduceMotion: reduceMotion)
        showHintArrow(for: node)
    }

    #if DEBUG
    func bridgePerformNextSolutionMove() {
        guard let id = state.validator.nextSuggestedRingId(clearedIds: state.clearedRingIds),
              let ring = level.ring(id),
              let node = ringNodes[id] else { return }
        let outcome = state.attempt(ringId: ring.id, dragDirection: ring.exitDirection)
        if outcome == .accepted {
            gameDelegate?.gameSceneRequestsHaptic(self, kind: .success)
            spawnReleaseFX(at: node.position, direction: ring.exitDirection)
            node.performExit(reduceMotion: reduceMotion) { [weak self] in
                guard let self else { return }
                self.gameDelegate?.gameScene(self, didChangeMoves: self.state.moveCount)
                if self.state.isComplete {
                    self.gameDelegate?.gameSceneRequestsHaptic(self, kind: .completion)
                    self.gameDelegate?.gameScene(self, didCompleteLevel: self.level, moves: self.state.moveCount)
                }
            }
        }
    }

    func bridgePerformInvalidMove() {
        // Pick the first locked ring (one with unmet requires) and try its direction.
        guard let blocked = level.rings.first(where: { ring in
            !state.clearedRingIds.contains(ring.id) && !ring.requires.allSatisfy { state.clearedRingIds.contains($0) }
        }), let node = ringNodes[blocked.id] else { return }
        let outcome = state.attempt(ringId: blocked.id, dragDirection: blocked.exitDirection)
        if case .blockedByPrerequisite = outcome {
            gameDelegate?.gameSceneRequestsHaptic(self, kind: .warning)
            spawnInvalidFX(at: node.position)
            node.snapBack(reduceMotion: reduceMotion) { [weak self] in
                guard let self else { return }
                self.gameDelegate?.gameScene(self, didChangeMoves: self.state.moveCount)
            }
        }
    }
    #endif

    private func rebuildScene() {
        removeAllChildren()
        ringNodes.removeAll(keepingCapacity: true)
        fxLayer = SKNode()
        fxLayer.zPosition = 500
        guard size.width > 0, size.height > 0 else { return }

        let padding: CGFloat = 16
        let usable = min(size.width, size.height) - padding * 2
        let cells = CGFloat(max(level.board.rows, level.board.cols))
        cellSize = usable / cells
        let boardWidth = cellSize * CGFloat(level.board.cols)
        let boardHeight = cellSize * CGFloat(level.board.rows)
        boardOrigin = CGPoint(
            x: (size.width - boardWidth) / 2,
            y: (size.height - boardHeight) / 2 + cellSize * 0.4
        )

        let frame = SKShapeNode(rect: CGRect(
            x: boardOrigin.x - cellSize * 0.18,
            y: boardOrigin.y - cellSize * 0.18,
            width: boardWidth + cellSize * 0.36,
            height: boardHeight + cellSize * 0.36
        ), cornerRadius: cellSize * 0.18)
        frame.strokeColor = UIColor(white: 0.16, alpha: 1.0)
        frame.lineWidth = 2
        frame.fillColor = UIColor(white: 0.04, alpha: 0.55)
        frame.zPosition = -999
        addChild(frame)

        let sorted = level.rings.sorted { $0.zIndex < $1.zIndex }
        for ring in sorted {
            let center = pointForCell(ring.cell)
            let node = RingNode(
                ring: ring,
                cellSize: cellSize,
                homePosition: center,
                reduceMotion: reduceMotion
            )
            node.name = ring.id
            node.isUserInteractionEnabled = false
            if state.clearedRingIds.contains(ring.id) {
                node.alpha = 0
            }
            ringNodes[ring.id] = node
            addChild(node)
        }
        addChild(fxLayer)
    }

    private func pointForCell(_ cell: Cell) -> CGPoint {
        let x = boardOrigin.x + (CGFloat(cell.col) + 0.5) * cellSize
        let y = boardOrigin.y + (CGFloat(level.board.rows - 1 - cell.row) + 0.5) * cellSize
        return CGPoint(x: x, y: y)
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        let candidates = nodes(at: point)
            .compactMap { $0 as? RingNode }
            .filter { !$0.isCleared }
        let topMost = candidates.max(by: { $0.zPosition < $1.zPosition })
        guard let target = topMost else {
            clearSelection()
            return
        }
        selectedNode?.showSelection(false)
        selectedNode = target
        dragStartLocation = point
        target.showSelection(true)
        showSelectionGlow(for: target)
        hideHintArrow()
        gameDelegate?.gameSceneRequestsHaptic(self, kind: .select)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let node = selectedNode else { return }
        let point = touch.location(in: self)
        let local = CGPoint(x: point.x - dragStartLocation.x, y: point.y - dragStartLocation.y)
        node.resistanceDrag(toLocal: local, exitVector: node.ring.exitDirection.unitVector)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let node = selectedNode else { return }
        let point = touch.location(in: self)
        let dx = point.x - dragStartLocation.x
        let dy = point.y - dragStartLocation.y
        let v = node.ring.exitDirection.unitVector
        let projection = dx * v.dx + dy * v.dy
        let cellUnits = projection / cellSize
        let threshold: CGFloat = 0.65
        if cellUnits >= threshold {
            let outcome = state.attempt(ringId: node.ring.id, dragDirection: node.ring.exitDirection)
            switch outcome {
            case .accepted:
                gameDelegate?.gameSceneRequestsHaptic(self, kind: .success)
                spawnReleaseFX(at: node.position, direction: node.ring.exitDirection)
                node.performExit(reduceMotion: reduceMotion) { [weak self] in
                    guard let self else { return }
                    self.gameDelegate?.gameScene(self, didChangeMoves: self.state.moveCount)
                    if self.state.isComplete {
                        self.gameDelegate?.gameSceneRequestsHaptic(self, kind: .completion)
                        self.gameDelegate?.gameScene(self, didCompleteLevel: self.level, moves: self.state.moveCount)
                    }
                }
            case .blockedByPrerequisite, .wrongDirection:
                gameDelegate?.gameSceneRequestsHaptic(self, kind: .warning)
                spawnInvalidFX(at: node.position)
                node.snapBack(reduceMotion: reduceMotion) { [weak self] in
                    guard let self else { return }
                    self.gameDelegate?.gameScene(self, didChangeMoves: self.state.moveCount)
                }
            case .alreadyCleared, .unknownRing:
                node.snapBack(reduceMotion: reduceMotion) {}
            }
        } else {
            node.snapBack(reduceMotion: reduceMotion) {}
        }
        hideSelectionGlow()
        clearSelection()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedNode?.snapBack(reduceMotion: reduceMotion) {}
        hideSelectionGlow()
        clearSelection()
    }

    private func clearSelection() {
        selectedNode?.showSelection(false)
        selectedNode = nil
    }

    // MARK: - FX

    private func showSelectionGlow(for node: RingNode) {
        hideSelectionGlow()
        guard let texture = textureNamed("fx_ring_selection_glow") else { return }
        let glow = SKSpriteNode(texture: texture)
        glow.size = CGSize(width: cellSize * 1.4, height: cellSize * 1.4)
        glow.alpha = 0.0
        glow.position = node.position
        glow.zPosition = node.zPosition - 0.1
        glow.blendMode = .add
        glow.run(SKAction.fadeAlpha(to: 0.95, duration: 0.12))
        fxLayer.addChild(glow)
        selectionGlowNode = glow
    }

    private func hideSelectionGlow() {
        if let glow = selectionGlowNode {
            glow.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.10),
                SKAction.removeFromParent()
            ]))
        }
        selectionGlowNode = nil
    }

    private func showHintArrow(for node: RingNode) {
        hideHintArrow()
        guard let texture = textureNamed("ui_drag_arrow_master") else { return }
        let arrow = SKSpriteNode(texture: texture)
        arrow.size = CGSize(width: cellSize * 0.9, height: cellSize * 0.9)
        let v = node.ring.exitDirection.unitVector
        arrow.position = CGPoint(
            x: node.position.x + v.dx * cellSize * 0.7,
            y: node.position.y + v.dy * cellSize * 0.7
        )
        arrow.zRotation = atan2(v.dy, v.dx)
        arrow.zPosition = 200
        arrow.alpha = 0
        fxLayer.addChild(arrow)
        hintArrowNode = arrow
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.18),
            SKAction.wait(forDuration: 0.8),
            SKAction.fadeAlpha(to: 0.0, duration: 0.25),
            SKAction.removeFromParent()
        ])
        arrow.run(pulse)
    }

    private func hideHintArrow() {
        hintArrowNode?.removeFromParent()
        hintArrowNode = nil
    }

    private func spawnReleaseFX(at point: CGPoint, direction: Direction) {
        guard let streakTexture = textureNamed("fx_ring_release_streak") else { return }
        let streak = SKSpriteNode(texture: streakTexture)
        streak.size = CGSize(width: cellSize * 2.2, height: cellSize * 0.6)
        streak.position = point
        streak.zRotation = direction.radians
        streak.blendMode = .add
        streak.alpha = 0.0
        streak.zPosition = 300
        fxLayer.addChild(streak)
        let v = direction.unitVector
        let endPoint = CGPoint(x: point.x + v.dx * cellSize * 1.4,
                               y: point.y + v.dy * cellSize * 1.4)
        let appear = SKAction.fadeAlpha(to: 0.85, duration: 0.08)
        let move = SKAction.move(to: endPoint, duration: 0.30)
        let fade = SKAction.fadeOut(withDuration: 0.30)
        streak.run(SKAction.sequence([
            appear,
            SKAction.group([move, fade]),
            SKAction.removeFromParent()
        ]))

        guard !reduceMotion, let sparkTexture = textureNamed("fx_metal_spark") else { return }
        for _ in 0..<6 {
            let spark = SKSpriteNode(texture: sparkTexture)
            spark.size = CGSize(width: cellSize * 0.45, height: cellSize * 0.45)
            spark.position = point
            spark.blendMode = .add
            spark.zPosition = 350
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let distance = CGFloat.random(in: cellSize * 0.4...cellSize * 1.0)
            let endP = CGPoint(x: point.x + cos(angle) * distance,
                               y: point.y + sin(angle) * distance)
            spark.alpha = 0.95
            fxLayer.addChild(spark)
            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(to: endP, duration: 0.28),
                    SKAction.scale(to: 0.3, duration: 0.28),
                    SKAction.fadeOut(withDuration: 0.28)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func spawnInvalidFX(at point: CGPoint) {
        guard !reduceMotion, let texture = textureNamed("fx_invalid_shockwave") else { return }
        let shock = SKSpriteNode(texture: texture)
        shock.size = CGSize(width: cellSize * 1.0, height: cellSize * 1.0)
        shock.position = point
        shock.blendMode = .add
        shock.alpha = 0.0
        shock.zPosition = 400
        fxLayer.addChild(shock)
        shock.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0.85, duration: 0.06),
                SKAction.scale(to: 1.0, duration: 0.06)
            ]),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.28),
                SKAction.scale(to: 1.6, duration: 0.28)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func textureNamed(_ name: String) -> SKTexture? {
        guard let image = UIImage(named: name) else { return nil }
        return SKTexture(image: image)
    }
}
