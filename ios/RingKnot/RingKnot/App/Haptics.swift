import CoreHaptics
import UIKit

/// Lightweight haptics wrapper built on `UIFeedbackGenerator` for reliability.
/// Silently no-ops when haptics are disabled in settings or the device has no
/// haptic hardware, so gameplay is never blocked by feedback.
@MainActor
final class Haptics {
    static let shared = Haptics()

    /// Driven by `Preferences`.
    var isEnabled: Bool = true

    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    private init() {}

    private var active: Bool { isEnabled && supportsHaptics }

    func prepare() {
        guard active else { return }
        light.prepare()
        heavy.prepare()
        notification.prepare()
    }

    /// Light tap for major UI controls (Play, Continue, settings, completion).
    func uiTap() {
        guard active else { return }
        light.impactOccurred(intensity: 0.5)
    }

    func fire(_ kind: HapticKind) {
        guard active else { return }
        switch kind {
        case .select:
            light.impactOccurred(intensity: 0.6)
        case .success:
            notification.notificationOccurred(.success)
        case .warning:
            notification.notificationOccurred(.warning)
        case .completion:
            // Stronger, layered feedback for finishing a level.
            notification.notificationOccurred(.success)
            heavy.impactOccurred(intensity: 0.9)
        }
    }
}
