import SpriteKit
import UIKit

protocol GameSceneDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didChangeMoves moves: Int)
    func gameScene(_ scene: GameScene, didCompleteLevel level: Level, moves: Int)
    func gameScene(_ scene: GameScene, didUpdateClearedCount count: Int)
    func gameSceneRequestsHaptic(_ scene: GameScene, kind: HapticKind)
    /// Fired once when the ring the tutorial is pointing at rolls into alignment,
    /// so the SwiftUI tutorial can advance from "rotate" to "pull".
    func gameSceneDidAlignSuggestedRing(_ scene: GameScene)
    /// Fired when the selected ring (or selection) changes, so the accessibility
    /// summary can mention whether the held ring is aligned.
    func gameSceneDidUpdateSelection(_ scene: GameScene)
}

enum HapticKind {
    case select
    case align
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
    private var previousLocation: CGPoint = .zero

    private var cellSize: CGFloat = 0
    private var boardOrigin: CGPoint = .zero

    private var fxLayer: SKNode = SKNode()
    private var hintArrowNode: SKSpriteNode?
    private var selectionGlowNode: SKSpriteNode?
    private var tutorialArrowNode: SKNode?
    private var tutorialActive = false

    weak var gameDelegate: GameSceneDelegate?

    /// Rings still on the board — used for the accessibility summary.
    var remainingRingCount: Int { level.rings.count - state.clearedRingIds.count }
    var totalRingCount: Int { level.rings.count }

    /// Accessibility: the held ring's id and whether its gap is aligned (nil when
    /// nothing is selected).
    private(set) var selectedRingId: String?
    var selectedRingIsAligned: Bool? {
        guard let id = selectedRingId, let node = ringNodes[id] else { return nil }
        return node.isAligned
    }

    /// Release happens when the gap is aligned and the player pulls the ring out
    /// along the exit: a clear projection beyond threshold plus genuine outward
    /// travel from the centre (so a tangential rotation never releases by accident).
    /// Tuned on the iPhone 17 Pro / SE simulators — see docs/gameplay/rotatable-rings.md.
    private var releaseProjectionThreshold: CGFloat { cellSize * 0.50 }
    private var releaseRadialThreshold: CGFloat { cellSize * 0.16 }
    /// Rotation only tracks once the finger is this far from the ring centre, so a
    /// touch near the hub does not produce wild angle jumps.
    private let rotationMinRadiusFactor: CGFloat = 0.10
    /// Magnetic snap window: within this many degrees of the exit the gap snaps
    /// exactly on. Kept small so the snap is a gentle assist, never a yank.
    private let snapDegrees: Double = 6

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

    /// Accessibility helper: roll the next solvable ring onto its exit so VoiceOver
    /// users can align without performing a rotation gesture. Then a normal pull
    /// (or the Show Hint action) finishes the move.
    func rotateSuggestedRingToExit() {
        guard let id = suggestedRingId(), let node = ringNodes[id] else { return }
        selectedNode?.showSelection(false)
        selectedNode = node
        selectedRingId = node.ring.id
        node.showSelection(true)
        node.alignGapToExit()
        gameDelegate?.gameSceneRequestsHaptic(self, kind: .align)
        if tutorialActive {
            gameDelegate?.gameSceneDidAlignSuggestedRing(self)
            refreshTutorialArrow(for: node)
        }
        gameDelegate?.gameSceneDidUpdateSelection(self)
    }

    // MARK: - Tutorial guidance (Level 1)

    /// Turns the persistent tutorial highlight + directional arrow on/off. The
    /// highlighted ring is always derived from the level's solution path, never
    /// a hardcoded id, so it stays correct across levels.
    func setTutorialGuidance(active: Bool) {
        tutorialActive = active
        if active {
            applyTutorialGuidance()
        } else {
            clearTutorialGuidance()
        }
    }

    private func applyTutorialGuidance() {
        clearTutorialGuidance()
        guard tutorialActive,
              let id = state.validator.nextSuggestedRingId(clearedIds: state.clearedRingIds),
              let node = ringNodes[id] else { return }
        node.setTutorialHighlight(true, reduceMotion: reduceMotion)
        refreshTutorialArrow(for: node)
    }

    /// Show the right cue for the highlighted ring: a curved "roll me" arc while
    /// the gap is still off, and the straight exit arrow once it is aligned.
    private func refreshTutorialArrow(for node: RingNode) {
        tutorialArrowNode?.removeFromParent()
        tutorialArrowNode = nil
        guard tutorialActive else { return }
        let cue: SKNode = node.isAligned ? makeExitArrow(for: node) : makeRotationCue(for: node)
        cue.zPosition = 220
        fxLayer.addChild(cue)
        tutorialArrowNode = cue
        guard !reduceMotion else { return }
        cue.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.45, duration: 0.6),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6)
        ])))
    }

    private func makeExitArrow(for node: RingNode) -> SKNode {
        let v = node.ring.exitDirection.sceneUnitVector
        guard let texture = textureNamed("ui_drag_arrow_master") else {
            // Procedural fallback so the cue still reads without the asset.
            let dot = SKShapeNode(circleOfRadius: cellSize * 0.1)
            dot.fillColor = RingPalette.readyGlow
            dot.strokeColor = .clear
            dot.position = CGPoint(x: node.position.x + v.dx * cellSize * 0.7,
                                   y: node.position.y + v.dy * cellSize * 0.7)
            return dot
        }
        let arrow = SKSpriteNode(texture: texture)
        arrow.size = CGSize(width: cellSize * 0.9, height: cellSize * 0.9)
        arrow.position = CGPoint(x: node.position.x + v.dx * cellSize * 0.7,
                                 y: node.position.y + v.dy * cellSize * 0.7)
        arrow.zRotation = node.ring.exitDirection.sceneRadians
        return arrow
    }

    /// A procedural curved arrow arcing around the ring, hinting "rotate me".
    /// Drawn with SKShapeNode so no bitmap asset is needed.
    private func makeRotationCue(for node: RingNode) -> SKNode {
        let container = SKNode()
        container.position = node.position
        let radius = cellSize * 0.62
        // Sweep the arc toward the exit so it reads as "roll the gap this way".
        let end = node.ring.exitDirection.sceneRadians
        let start = end - .pi * 0.9
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        let arc = SKShapeNode(path: path)
        arc.strokeColor = RingPalette.hintGlow
        arc.lineWidth = 3.5
        arc.lineCap = .round
        arc.fillColor = .clear
        container.addChild(arc)

        // Arrowhead at the leading (exit) end of the arc.
        let tip = CGPoint(x: cos(end) * radius, y: sin(end) * radius)
        let tangent = end + .pi / 2          // direction of travel along the arc
        let headLength = cellSize * 0.18
        let headWidth = cellSize * 0.12
        let back = CGPoint(x: tip.x - cos(tangent) * headLength,
                           y: tip.y - sin(tangent) * headLength)
        let left = CGPoint(x: back.x - cos(end) * headWidth, y: back.y - sin(end) * headWidth)
        let right = CGPoint(x: back.x + cos(end) * headWidth, y: back.y + sin(end) * headWidth)
        let head = CGMutablePath()
        head.move(to: tip)
        head.addLine(to: left)
        head.addLine(to: right)
        head.closeSubpath()
        let headNode = SKShapeNode(path: head)
        headNode.fillColor = RingPalette.hintGlow
        headNode.strokeColor = .clear
        container.addChild(headNode)
        return container
    }

    private func clearTutorialGuidance() {
        tutorialArrowNode?.removeFromParent()
        tutorialArrowNode = nil
        for node in ringNodes.values {
            node.setTutorialHighlight(false, reduceMotion: reduceMotion)
        }
    }

    #if DEBUG
    private func nextSolutionNode() -> RingNode? {
        guard let id = state.validator.nextSuggestedRingId(clearedIds: state.clearedRingIds) else { return nil }
        return ringNodes[id]
    }

    private func selectForBridge(_ node: RingNode) {
        selectedNode?.showSelection(false)
        selectedNode = node
        selectedRingId = node.ring.id
        node.showSelection(true)
        gameDelegate?.gameSceneDidUpdateSelection(self)
    }

    /// Roll the next solution ring exactly onto its exit (no drag needed).
    func bridgeRotateNextSolutionRingToAligned() {
        guard let node = nextSolutionNode() else { return }
        selectForBridge(node)
        node.alignGapToExit()
        gameDelegate?.gameSceneRequestsHaptic(self, kind: .align)
        if tutorialActive, node.ring.id == suggestedRingId() {
            gameDelegate?.gameSceneDidAlignSuggestedRing(self)
            refreshTutorialArrow(for: node)
        }
        gameDelegate?.gameSceneDidUpdateSelection(self)
    }

    /// Force the next solution ring's gap to a clearly misaligned angle.
    func bridgeRotateSelectedRingToMisaligned() {
        guard let node = nextSolutionNode() else { return }
        selectForBridge(node)
        node.setGapMisaligned()
        if tutorialActive, node.ring.id == suggestedRingId() {
            refreshTutorialArrow(for: node)
        }
        gameDelegate?.gameSceneDidUpdateSelection(self)
    }

    /// Attempt to pull the next solution ring out using its *current* gap. Removes
    /// it only if aligned and unblocked — the deterministic hook UI tests use to
    /// prove alignment is enforced.
    func bridgeTryReleaseNextSolutionRing() {
        guard let node = nextSolutionNode() else { return }
        releaseSelected(node)
    }

    /// Align then release in one deterministic step (a full rotation-aware move).
    func bridgePerformNextSolutionMoveWithRotation() {
        guard let node = nextSolutionNode() else { return }
        node.alignGapToExit()
        releaseSelected(node)
    }

    /// Legacy hook kept for the Phase 2/3 completion + unlock tests: aligns then
    /// releases the next solution ring (same observable result as before — the
    /// move counter advances and the ring exits).
    func bridgePerformNextSolutionMove() {
        bridgePerformNextSolutionMoveWithRotation()
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
                rotation: level.rotation(for: ring),
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
        if tutorialActive { applyTutorialGuidance() }
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
        selectedRingId = target.ring.id
        dragStartLocation = point
        previousLocation = point
        target.showSelection(true)
        showSelectionGlow(for: target)
        hideHintArrow()
        gameDelegate?.gameSceneRequestsHaptic(self, kind: .select)
        gameDelegate?.gameSceneDidUpdateSelection(self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let node = selectedNode else { return }
        let point = touch.location(in: self)
        let center = node.homePosition

        // 1. Rotation: roll the gap by the angular change of the finger around the
        //    ring centre. Radial (pull) motion barely changes this angle, so it
        //    does not spin the ring — exactly what we want.
        let radius = hypot(point.x - center.x, point.y - center.y)
        if radius > cellSize * rotationMinRadiusFactor {
            let prevAngle = atan2(previousLocation.y - center.y, previousLocation.x - center.x)
            let curAngle = atan2(point.y - center.y, point.x - center.x)
            let delta = atan2(sin(curAngle - prevAngle), cos(curAngle - prevAngle))
            if delta != 0 {
                let wasAligned = node.isAligned
                _ = node.rotateGap(byRadians: delta, snapDegrees: snapDegrees)
                // One subtle tick on the alignment transition only — never a second
                // haptic for the snap, so rolling past the window feels clean.
                if node.isAligned != wasAligned {
                    if node.isAligned {
                        gameDelegate?.gameSceneRequestsHaptic(self, kind: .align)
                        if tutorialActive, node.ring.id == suggestedRingId() {
                            gameDelegate?.gameSceneDidAlignSuggestedRing(self)
                        }
                    }
                    if tutorialActive, node.ring.id == suggestedRingId() {
                        refreshTutorialArrow(for: node)
                    }
                    gameDelegate?.gameSceneDidUpdateSelection(self)
                }
            }
        }

        // 2. Pull feedback: only an aligned ring slides outward along its exit.
        let exit = node.ring.exitDirection.sceneUnitVector
        let fromStart = CGPoint(x: point.x - dragStartLocation.x, y: point.y - dragStartLocation.y)
        let projection = fromStart.x * exit.dx + fromStart.y * exit.dy
        if node.isAligned && projection > 0 {
            node.pullAlong(exitVector: exit, distance: projection)
        } else {
            node.settleHome(reduceMotion: reduceMotion)
        }

        previousLocation = point
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let node = selectedNode else {
            clearSelection()
            return
        }
        let point = touch.location(in: self)
        let center = node.homePosition
        let exit = node.ring.exitDirection.sceneUnitVector

        let fromStart = CGPoint(x: point.x - dragStartLocation.x, y: point.y - dragStartLocation.y)
        let projection = fromStart.x * exit.dx + fromStart.y * exit.dy
        let startRadius = hypot(dragStartLocation.x - center.x, dragStartLocation.y - center.y)
        let endRadius = hypot(point.x - center.x, point.y - center.y)
        let radialGain = endRadius - startRadius

        let isPull = projection >= releaseProjectionThreshold && radialGain >= releaseRadialThreshold

        if isPull {
            if node.isAligned {
                releaseSelected(node)
            } else {
                // Pulled before lining the gap up: refuse, nudge, ask to rotate.
                gameDelegate?.gameSceneRequestsHaptic(self, kind: .warning)
                spawnInvalidFX(at: node.position)
                node.snapBack(reduceMotion: reduceMotion) {}
                if tutorialActive, node.ring.id == suggestedRingId() {
                    refreshTutorialArrow(for: node)
                }
            }
        } else {
            // Pure rotation (or a too-short pull): keep the rolled gap, settle home.
            node.settleHome(reduceMotion: reduceMotion)
        }
        hideSelectionGlow()
        clearSelection()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedNode?.settleHome(reduceMotion: reduceMotion)
        hideSelectionGlow()
        clearSelection()
    }

    /// Apply the rotation-aware release rules to the selected ring and animate.
    private func releaseSelected(_ node: RingNode) {
        let outcome = state.attemptRelease(ringId: node.ring.id, gapAngleDegrees: node.gapAngleDegrees)
        switch outcome {
        case .accepted:
            gameDelegate?.gameSceneRequestsHaptic(self, kind: .success)
            spawnReleaseFX(at: node.position, direction: node.ring.exitDirection)
            node.performExit(reduceMotion: reduceMotion) { [weak self] in
                guard let self else { return }
                self.gameDelegate?.gameScene(self, didChangeMoves: self.state.moveCount)
                self.gameDelegate?.gameScene(self, didUpdateClearedCount: self.state.clearedRingIds.count)
                if self.tutorialActive { self.applyTutorialGuidance() }
                if self.state.isComplete {
                    self.gameDelegate?.gameSceneRequestsHaptic(self, kind: .completion)
                    self.gameDelegate?.gameScene(self, didCompleteLevel: self.level, moves: self.state.moveCount)
                }
            }
        case .blockedByPrerequisite:
            gameDelegate?.gameSceneRequestsHaptic(self, kind: .warning)
            spawnInvalidFX(at: node.position)
            node.snapBack(reduceMotion: reduceMotion) {}
        case .notAligned, .wrongDirection, .alreadyCleared, .unknownRing:
            node.snapBack(reduceMotion: reduceMotion) {}
        }
    }

    private func clearSelection() {
        selectedNode?.showSelection(false)
        selectedNode = nil
        selectedRingId = nil
        gameDelegate?.gameSceneDidUpdateSelection(self)
    }

    private func suggestedRingId() -> String? {
        state.validator.nextSuggestedRingId(clearedIds: state.clearedRingIds)
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
        let v = node.ring.exitDirection.sceneUnitVector
        arrow.position = CGPoint(
            x: node.position.x + v.dx * cellSize * 0.7,
            y: node.position.y + v.dy * cellSize * 0.7
        )
        arrow.zRotation = node.ring.exitDirection.sceneRadians
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
        streak.zRotation = direction.sceneRadians
        streak.blendMode = .add
        streak.alpha = 0.0
        streak.zPosition = 300
        fxLayer.addChild(streak)
        let v = direction.sceneUnitVector
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
