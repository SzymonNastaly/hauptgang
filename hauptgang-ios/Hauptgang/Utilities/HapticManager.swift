import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        self.lightImpact.prepare()
    }

    func lightTap() {
        self.lightImpact.impactOccurred()
    }

    func selection() {
        self.selectionGenerator.selectionChanged()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        self.notificationGenerator.notificationOccurred(type)
    }
}
