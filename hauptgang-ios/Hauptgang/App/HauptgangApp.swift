import RevenueCat
import SwiftData
import SwiftUI

@main
struct HauptgangApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var subscriptionManager = SubscriptionManager()

    init() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Constants.RevenueCat.apiKey)
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PersistedRecipe.self,
            PersistedShoppingListItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(self.authManager)
                .environmentObject(self.subscriptionManager)
                .task {
                    await subscriptionManager.refreshStatus()
                }
        }
        .modelContainer(self.sharedModelContainer)
    }
}
