import SwiftUI

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        NavigationStack {
            if let error = environment.loadError {
                LoadFailureView(error: error)
            } else {
                HomeView()
            }
        }
        .tint(Color(red: 0.95, green: 0.65, blue: 0.35))
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
