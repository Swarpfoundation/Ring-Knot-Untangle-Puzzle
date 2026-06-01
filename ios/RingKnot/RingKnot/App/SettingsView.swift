import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            BackgroundImage(name: "bg_menu_obsidian_portrait",
                            fallback: [Color.black, Color(red: 0.06, green: 0.04, blue: 0.02)])
            List {
                Section("Sound & Haptics") {
                    Toggle("Sound", isOn: $preferences.soundEnabled)
                        .accessibilityIdentifier("settings.sound")
                        .onChange(of: preferences.soundEnabled) { _, on in
                            if on { AudioManager.shared.play(.buttonTap) }
                        }
                    Toggle("Haptics", isOn: $preferences.hapticsEnabled)
                        .accessibilityIdentifier("settings.haptics")
                        .onChange(of: preferences.hapticsEnabled) { _, on in
                            if on { Haptics.shared.uiTap() }
                        }
                }

                Section("Guidance") {
                    Button("Replay onboarding") {
                        Haptics.shared.uiTap()
                        preferences.onboardingCompleted = false
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.replayOnboarding")

                    Button("Replay Level 1 tutorial") {
                        Haptics.shared.uiTap()
                        preferences.level1TutorialCompleted = false
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.replayTutorial")
                }

                Section("Progress") {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Text("Reset progress")
                    }
                    .accessibilityIdentifier("settings.reset")
                }

                Section("About") {
                    Text("Original puzzle art and code. No third-party assets or tracking SDKs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.credits")
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionString)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Version \(versionString)")
                    .accessibilityIdentifier("settings.version")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset all progress?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Haptics.shared.uiTap()
                environment.resetProgress()
                dismiss()
            }
            .accessibilityIdentifier("settings.resetConfirm")
        } message: {
            Text("This clears completed levels, best scores, and replays the intro. This cannot be undone.")
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
