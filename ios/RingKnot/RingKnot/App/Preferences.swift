import Foundation
import SwiftUI

/// Single typed source of truth for user-facing settings and first-session flags.
/// All persisted keys live here so raw UserDefaults strings are never scattered
/// across the app. Changes are pushed to the audio and haptics singletons.
@MainActor
final class Preferences: ObservableObject {
    private enum Key {
        static let sound = "com.swarpfoundation.ringknot.pref.sound.enabled"
        static let haptics = "com.swarpfoundation.ringknot.pref.haptics.enabled"
        static let onboarding = "com.swarpfoundation.ringknot.pref.onboarding.completed"
        static let level1Tutorial = "com.swarpfoundation.ringknot.pref.tutorial.level1.completed"
    }

    private let defaults: UserDefaults

    @Published var soundEnabled: Bool {
        didSet {
            defaults.set(soundEnabled, forKey: Key.sound)
            AudioManager.shared.isEnabled = soundEnabled
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet {
            defaults.set(hapticsEnabled, forKey: Key.haptics)
            Haptics.shared.isEnabled = hapticsEnabled
        }
    }

    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboarding) }
    }

    @Published var level1TutorialCompleted: Bool {
        didSet { defaults.set(level1TutorialCompleted, forKey: Key.level1Tutorial) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Settings default to on; first-session flags default to false.
        self.soundEnabled = (defaults.object(forKey: Key.sound) as? Bool) ?? true
        self.hapticsEnabled = (defaults.object(forKey: Key.haptics) as? Bool) ?? true
        self.onboardingCompleted = defaults.bool(forKey: Key.onboarding)
        self.level1TutorialCompleted = defaults.bool(forKey: Key.level1Tutorial)
        syncManagers()
    }

    /// Push current toggle values into the audio/haptics singletons.
    func syncManagers() {
        AudioManager.shared.isEnabled = soundEnabled
        Haptics.shared.isEnabled = hapticsEnabled
    }

    /// Re-show onboarding and the Level 1 tutorial (used by Settings + reset).
    func replayIntros() {
        onboardingCompleted = false
        level1TutorialCompleted = false
    }

    #if DEBUG
    /// Test hooks driven by launch arguments so UI tests get deterministic state.
    func applyUITestOverrides(_ arguments: [String]) {
        // Skip both intros (most gameplay tests want to land straight on Home).
        if arguments.contains("-uiTestSkipIntro") {
            onboardingCompleted = true
            level1TutorialCompleted = true
        }
        // Re-arm both intros (onboarding test).
        if arguments.contains("-uiTestResetIntros") {
            onboardingCompleted = false
            level1TutorialCompleted = false
        }
        // Skip onboarding but arm the Level 1 tutorial (tutorial test).
        if arguments.contains("-uiTestResetTutorial") {
            onboardingCompleted = true
            level1TutorialCompleted = false
        }
        if arguments.contains("-uiTestSoundOff") {
            soundEnabled = false
        }
    }
    #endif
}
