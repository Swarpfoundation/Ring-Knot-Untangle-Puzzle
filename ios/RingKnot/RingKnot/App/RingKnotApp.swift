import SwiftUI

@main
struct RingKnotApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(environment.preferences)
                .preferredColorScheme(.dark)
        }
    }
}
