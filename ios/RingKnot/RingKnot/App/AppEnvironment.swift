import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    @Published private(set) var levelPack: LevelPack
    @Published private(set) var progress: ProgressSnapshot
    let store: ProgressStore
    let preferences: Preferences
    let loadError: LevelLoaderError?

    init(store: ProgressStore = ProgressStore(), preferences: Preferences? = nil) {
        self.store = store
        // Built inside the (main-actor) body: Preferences is @MainActor, so it
        // cannot be a nonisolated default-argument expression.
        let preferences = preferences ?? Preferences()
        self.preferences = preferences
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-com.swarpfoundation.ringknot.resetProgress") {
            store.reset()
        }
        // UI-test only: unlock every level so screenshot tours can open mid/late
        // levels deterministically. DEBUG-gated, never compiled into Release.
        if arguments.contains("-uiTestUnlockAll") {
            store.save(ProgressSnapshot(unlockedLevelID: 20))
        }
        preferences.applyUITestOverrides(arguments)
        #endif
        Haptics.shared.prepare()
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

    func isCompleted(_ levelID: Int) -> Bool {
        progress.records[levelID]?.completed == true
    }

    func record(_ levelID: Int, moves: Int) {
        let total = levelPack.levels.count
        progress = store.record(completion: levelID, moves: moves, totalLevels: total)
    }

    func nextLevelID(after levelID: Int) -> Int? {
        let next = levelID + 1
        return levelPack.levels.contains(where: { $0.id == next }) ? next : nil
    }

    /// The level the "Continue" button resumes: the highest unlocked level that
    /// is not yet completed. Because unlocks are sequential this is normally the
    /// player's frontier level. Returns nil when every unlocked level is done.
    var continueTargetID: Int? {
        let unlockedIncomplete = levelPack.levels
            .map(\.id)
            .filter { isUnlocked($0) && !isCompleted($0) }
        return unlockedIncomplete.max()
    }

    /// True once the player has started playing (any completion recorded or
    /// unlocked beyond level 1).
    var hasProgress: Bool {
        progress.unlockedLevelID > 1 || !progress.records.isEmpty
    }

    /// Clears all gameplay progress and re-arms onboarding/tutorial.
    func resetProgress() {
        store.reset()
        progress = store.load()
        preferences.replayIntros()
    }
}
