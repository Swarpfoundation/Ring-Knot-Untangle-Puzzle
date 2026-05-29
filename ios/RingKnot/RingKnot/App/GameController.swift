import Combine
import Foundation
import SpriteKit

/// Stats shown on the completion screen for the run that just finished.
struct CompletionInfo: Equatable {
    let levelID: Int
    let moves: Int
    let par: Int
    let best: Int
    let isNewBest: Bool
    let isLastLevel: Bool
}

@MainActor
final class GameController: NSObject, ObservableObject, GameSceneDelegate {
    @Published private(set) var moves: Int = 0
    @Published private(set) var clearedCount: Int = 0
    @Published private(set) var didComplete: Bool = false
    @Published private(set) var completion: CompletionInfo?

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
        clearedCount = 0
        didComplete = false
        completion = nil
        return scene
    }

    func replaceLevel(with level: Level, reduceMotion: Bool) {
        _ = scene(for: level, reduceMotion: reduceMotion)
    }

    func restart() {
        currentScene?.restart()
        moves = 0
        clearedCount = 0
        didComplete = false
        completion = nil
    }

    func hint() {
        currentScene?.highlightHint()
    }

    func setTutorialGuidance(active: Bool) {
        currentScene?.setTutorialGuidance(active: active)
    }

    /// Accessibility summary of the board for the current level.
    var boardAccessibilitySummary: String {
        guard let scene = currentScene, let id = currentLevelID else { return "Game board" }
        return "Level \(id) board. \(scene.remainingRingCount) of \(scene.totalRingCount) rings remaining."
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

    nonisolated func gameScene(_ scene: GameScene, didUpdateClearedCount count: Int) {
        Task { @MainActor in self.clearedCount = count }
    }

    nonisolated func gameScene(_ scene: GameScene, didCompleteLevel level: Level, moves: Int) {
        Task { @MainActor in
            guard let environment = self.environment else { return }
            let previousBest = environment.progress.records[level.id]?.bestMoveCount
            environment.record(level.id, moves: moves)
            let best = environment.progress.records[level.id]?.bestMoveCount ?? moves
            let isNewBest = previousBest == nil || moves < (previousBest ?? Int.max)
            self.completion = CompletionInfo(
                levelID: level.id,
                moves: moves,
                par: level.solution.count,
                best: best,
                isNewBest: isNewBest,
                isLastLevel: environment.nextLevelID(after: level.id) == nil
            )
            self.didComplete = true
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
