import SwiftUI

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var preferences: Preferences
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            if let error = environment.loadError {
                LoadFailureView(error: error)
            } else {
                HomeView()
            }
        }
        .tint(Color(red: 0.95, green: 0.65, blue: 0.35))
        .onAppear {
            if !preferences.onboardingCompleted && environment.loadError == nil {
                showOnboarding = true
            }
        }
        .onChange(of: preferences.onboardingCompleted) { _, completed in
            // Settings "Replay onboarding" flips this back to false.
            if !completed && environment.loadError == nil {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
            preferences.onboardingCompleted = true
        }) {
            OnboardingView(onFinish: {
                preferences.onboardingCompleted = true
                showOnboarding = false
            })
        }
    }
}

private struct LoadFailureView: View {
    let error: LevelLoaderError

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                Text("Level pack failed to load")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(String(describing: error))
                    .font(.callout)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
