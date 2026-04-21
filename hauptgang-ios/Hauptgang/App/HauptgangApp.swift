import os
import RevenueCat
import Sentry
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "app.hauptgang.ios", category: "App")

@main
struct HauptgangApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var subscriptionManager = SubscriptionManager()

    init() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Constants.RevenueCat.apiKey)

        SentrySDK.start { options in
            options.dsn = Constants.Sentry.dsn
            options.environment = Constants.Sentry.environment
            options.tracesSampleRate = 0.1
            options.configureProfiling = { profiling in
                profiling.lifecycle = .trace
                profiling.sessionSampleRate = 0.1
            }
            options.enableMetricKit = true
            options.enableTimeToFullDisplayTracing = true

            // GDPR: do not send PII
            options.sendDefaultPii = false

            #if DEBUG
            options.debug = true
            options.enabled = false
            #endif
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: HauptgangSchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Happy path: versioned store opens with migration plan
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: HauptgangMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            // Existing store is unversioned (pre-cookbook TestFlight builds) or corrupted.
            // Nuke the store — all data re-syncs from the server.
            logger.warning("ModelContainer failed, nuking store: \(error.localizedDescription)")
            Self.deleteStore(at: config.url)
        }

        // Second attempt: fresh store, no migration needed
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer after reset: \(error)")
        }
    }()

    @State private var deepLinkRouter = DeepLinkRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(self.authManager)
                .environmentObject(self.subscriptionManager)
                .environment(self.deepLinkRouter)
                .environment(NetworkMonitor.shared)
                .preferredColorScheme(.light)
                .task {
                    self.subscriptionManager.startListening()
                    await self.subscriptionManager.refreshStatus()
                }
                .onOpenURL { url in
                    self.deepLinkRouter.handle(url)
                }
        }
        .modelContainer(self.sharedModelContainer)
    }

    /// Delete a SwiftData/SQLite store and all associated files
    private static func deleteStore(at url: URL) {
        let fm = FileManager.default
        // SQLite uses companion -wal and -shm files
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = suffix.isEmpty ? url : URL(fileURLWithPath: url.path + suffix)
            if fm.fileExists(atPath: fileURL.path) {
                do {
                    try fm.removeItem(at: fileURL)
                    logger.info("Deleted store file: \(fileURL.lastPathComponent)")
                } catch {
                    logger.error("Failed to delete \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
    }
}
