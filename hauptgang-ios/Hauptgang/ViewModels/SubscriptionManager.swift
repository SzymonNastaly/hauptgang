import Foundation
import os
import RevenueCat
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "Subscription")

/// Manages RevenueCat subscription state
/// Injected as an environment object for global access
@MainActor
final class SubscriptionManager: NSObject, ObservableObject, PurchasesDelegate {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoaded: Bool = false

    func startListening() {
        Purchases.shared.delegate = self
        logger.info("startListening() — set as PurchasesDelegate")
    }

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        logger.info("delegate receivedUpdated customerInfo for: \(customerInfo.originalAppUserId)")
        Task { @MainActor in
            self.updateProStatus(from: customerInfo)
        }
    }

    func identify(userId: String) async {
        logger.info("identify() called with userId: \(userId)")
        do {
            let (customerInfo, created) = try await Purchases.shared.logIn(userId)
            logger.info("identify() logIn succeeded — created: \(created), appUserID: \(customerInfo.originalAppUserId)")
            self.updateProStatus(from: customerInfo)
        } catch {
            logger.error("identify() logIn failed: \(error.localizedDescription)")
        }
    }

    func reset() async {
        logger.info("reset() called")
        do {
            let customerInfo = try await Purchases.shared.logOut()
            logger.info("reset() logOut succeeded")
            self.updateProStatus(from: customerInfo)
        } catch {
            logger.error("reset() logOut failed: \(error.localizedDescription)")
            self.isPro = false
        }
    }

    func refreshStatus() async {
        logger.info("refreshStatus() called — current appUserID: \(Purchases.shared.appUserID)")
        do {
            let customerInfo = try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
            logger.info("refreshStatus() fetched customerInfo for: \(customerInfo.originalAppUserId)")
            self.updateProStatus(from: customerInfo)
        } catch {
            logger.error("refreshStatus() failed: \(error.localizedDescription)")
        }
        self.isLoaded = true
    }

    private func updateProStatus(from customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements[Constants.RevenueCat.entitlementID]
        let isActive = entitlement?.isActive == true
        logger.info("""
        updateProStatus() — entitlementID: \(Constants.RevenueCat.entitlementID), \
        found: \(entitlement != nil), \
        isActive: \(isActive), \
        isPro: \(self.isPro) → \(isActive)
        """)
        self.isPro = isActive
    }
}
