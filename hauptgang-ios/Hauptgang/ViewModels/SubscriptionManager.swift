import Foundation
import RevenueCat
import SwiftUI

/// Manages RevenueCat subscription state
/// Injected as an environment object for global access
@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoaded: Bool = false

    func identify(userId: String) async {
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            self.updateProStatus(from: customerInfo)
        } catch {
            // Failed to identify — keep current state
        }
    }

    func reset() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.updateProStatus(from: customerInfo)
        } catch {
            self.isPro = false
        }
    }

    func refreshStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.updateProStatus(from: customerInfo)
        } catch {
            // Failed to fetch — keep current state
        }
        self.isLoaded = true
    }

    private func updateProStatus(from customerInfo: CustomerInfo) {
        self.isPro = customerInfo.entitlements[Constants.RevenueCat.entitlementID]?.isActive == true
    }
}
