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

    weak var gameDelegate: GameSceneDelegate?

    init(level: Level, reduceMotion: Bool) {
        self.level = level
        self.state = GameState(level: level)
        self.reduceMotion = reduceMotion
        super.init(size: .zero)
        scaleMode = .resizeFill
        backgroundColor = RingPalette.boardBackground
    }

    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
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
    }

    private func rebuildScene() {
        removeAllChildren()
        ringNodes.removeAll(keepingCapacity: true)
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

        let bgSize = CGSize(width: boardWidth + cellSize * 0.4, height: boardHeight + cellSize * 0.4)
        let bgTexture = RingTextureFactory.boardBackgroundTexture(size: bgSize)
        let bg = SKSpriteNode(texture: bgTexture, size: bgSize)
        bg.position = CGPoint(x: boardOrigin.x + boardWidth / 2, y: boardOrigin.y + boardHeight / 2)
        bg.zPosition = -1000
        addChild(bg)

        let frame = SKShapeNode(rect: CGRect(origin: .zero, size: bgSize), cornerRadius: cellSize * 0.18)
        frame.position = CGPoint(x: bg.position.x - bgSize.width / 2, y: bg.position.y - bgSize.height / 2)
        frame.strokeColor = UIColor(white: 0.18, alpha: 1.0)
        frame.lineWidth = 2
        frame.fillColor = .clear
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
    }

    private func pointForCell(_ cell: Cell) -> CGPoint {
        let x = boardOrigin.x + (CGFloat(cell.col) + 0.5) * cellSize
        let y = boardOrigin.y + (CGFloat(level.board.rows - 1 - cell.row) + 0.5) * cellSize
        return CGPoint(x: x, y: y)
    }

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
        clearSelection()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedNode?.snapBack(reduceMotion: reduceMotion) {}
        clearSelection()
    }

    private func clearSelection() {
        selectedNode?.showSelection(false)
        selectedNode = nil
    }
}
