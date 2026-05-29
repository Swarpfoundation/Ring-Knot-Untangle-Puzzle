import SwiftUI

@main
struct RingKnotApp: App {
    @StateObject private var environment = AppEnvironment()

    init() {
        Haptics.shared.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .preferredColorScheme(.dark)
        }
    }
}
