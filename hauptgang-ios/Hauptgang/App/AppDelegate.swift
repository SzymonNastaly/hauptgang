import UIKit

/// Bridges UIKit AppDelegate callbacks (notably APNs registration) into our
/// SwiftUI app. Wired via `@UIApplicationDelegateAdaptor` in `HauptgangApp`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await PushNotificationService.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task {
            await PushNotificationService.shared.handleRegistrationFailure(error)
        }
    }
}
