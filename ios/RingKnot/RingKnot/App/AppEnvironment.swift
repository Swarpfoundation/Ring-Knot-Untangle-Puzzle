import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    @Published private(set) var levelPack: LevelPack
    @Published private(set) var progress: ProgressSnapshot
    let store: ProgressStore
    let loadError: LevelLoaderError?

    init() {
        let store = ProgressStore()
        self.store = store
        do {
            let pack = try LevelLoader.loadDefault()
            self.levelPack = pack
            self.loadError = nil
        } catch let error as LevelLoaderError {
            self.levelPack = LevelPack(game: "Ring Knot", version: "0.0.0", levels: [])
            self.loadError = error
        } catch {
            self.levelPack = LevelPack(game: "Ring Knot", version: "0.0.0", levels: [])
            self.loadError = .malformedJSON(error.localizedDescription)
        }
        self.progress = store.load()
    }

    func isUnlocked(_ levelID: Int) -> Bool {
        levelID <= progress.unlockedLevelID
    }

    func record(_ levelID: Int, moves: Int) {
        let total = levelPack.levels.count
        progress = store.record(completion: levelID, moves: moves, totalLevels: total)
    }

    func nextLevelID(after levelID: Int) -> Int? {
        let next = levelID + 1
        return levelPack.levels.contains(where: { $0.id == next }) ? next : nil
    }
}
