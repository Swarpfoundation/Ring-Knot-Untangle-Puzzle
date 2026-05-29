import UIKit

final class Haptics {
    static let shared = Haptics()

    private let select = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()

    private init() {}

    func prepare() {
        select.prepare()
        notification.prepare()
    }

    func fire(_ kind: HapticKind) {
        switch kind {
        case .select:
            select.impactOccurred(intensity: 0.6)
        case .success:
            notification.notificationOccurred(.success)
        case .warning:
            notification.notificationOccurred(.warning)
        case .completion:
            notification.notificationOccurred(.success)
        }
    }
}
