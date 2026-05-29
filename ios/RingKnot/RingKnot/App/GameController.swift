import Combine
import Foundation
import SpriteKit

@MainActor
final class GameController: NSObject, ObservableObject, GameSceneDelegate {
    @Published private(set) var moves: Int = 0
    @Published private(set) var didComplete: Bool = false

    private var currentScene: GameScene?
    private weak var environment: AppEnvironment?
    private var currentLevelID: Int?

    func bind(environment: AppEnvironment) {
        self.environment = environment
    }

    @discardableResult
    func scene(for level: Level, reduceMotion: Bool) -> GameScene {
        if let existing = currentScene, currentLevelID == level.id {
            return existing
        }
        let scene = GameScene(level: level, reduceMotion: reduceMotion)
        scene.gameDelegate = self
        currentScene = scene
        currentLevelID = level.id
        moves = 0
        didComplete = false
        return scene
    }

    func replaceLevel(with level: Level, reduceMotion: Bool) {
        _ = scene(for: level, reduceMotion: reduceMotion)
    }

    func restart() {
        currentScene?.restart()
        moves = 0
        didComplete = false
    }

    func hint() {
        currentScene?.highlightHint()
    }

    #if DEBUG
    func bridgePerformNextSolutionMove() {
        currentScene?.bridgePerformNextSolutionMove()
    }

    func bridgePerformInvalidMove() {
        currentScene?.bridgePerformInvalidMove()
    }
    #endif

    nonisolated func gameScene(_ scene: GameScene, didChangeMoves moves: Int) {
        Task { @MainActor in self.moves = moves }
    }

    nonisolated func gameScene(_ scene: GameScene, didCompleteLevel level: Level, moves: Int) {
        Task { @MainActor in
            self.didComplete = true
            self.environment?.record(level.id, moves: moves)
        }
    }

    nonisolated func gameSceneRequestsHaptic(_ scene: GameScene, kind: HapticKind) {
        Task { @MainActor in
            Haptics.shared.fire(kind)
            switch kind {
            case .select:     AudioManager.shared.play(.ringSelect)
            case .success:    AudioManager.shared.play(.ringRelease)
            case .warning:    AudioManager.shared.play(.ringInvalid)
            case .completion: AudioManager.shared.play(.levelComplete)
            }
        }
    }
}
