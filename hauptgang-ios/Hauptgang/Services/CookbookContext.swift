import Foundation
import os

/// Manages the active cookbook selection, persisted to app-group UserDefaults
/// so the share extension can read which cookbook to import into.
actor CookbookContext {
    static let shared = CookbookContext()

    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "CookbookContext")
    private let defaults: UserDefaults

    private var activeCookbookId: Int?
    private var currentUserId: Int?

    private init() {
        if let groupDefaults = UserDefaults(suiteName: "group.app.hauptgang.shared") {
            self.defaults = groupDefaults
        } else {
            self.defaults = .standard
        }
    }

    /// Configure with the current user and load their saved cookbook selection
    func configure(userId: Int) {
        self.currentUserId = userId
        self.activeCookbookId = self.defaults.object(forKey: self.key(for: userId)) as? Int
        self.logger.info("Configured for user \(userId), active cookbook: \(self.activeCookbookId ?? -1)")
    }

    /// Get the currently active cookbook ID (nil means server will default to personal)
    func getActiveCookbookId() -> Int? {
        self.activeCookbookId
    }

    /// Set the active cookbook and persist the selection
    func setActiveCookbookId(_ cookbookId: Int?) {
        self.activeCookbookId = cookbookId
        guard let userId = self.currentUserId else { return }

        if let cookbookId {
            self.defaults.set(cookbookId, forKey: self.key(for: userId))
        } else {
            self.defaults.removeObject(forKey: self.key(for: userId))
        }

        self.logger.info("Set active cookbook to \(cookbookId ?? -1) for user \(userId)")
    }

    /// Clear all state (e.g., on logout)
    func reset() {
        if let userId = self.currentUserId {
            self.defaults.removeObject(forKey: self.key(for: userId))
        }
        self.activeCookbookId = nil
        self.currentUserId = nil
    }

    // MARK: - Private

    private func key(for userId: Int) -> String {
        "activeCookbook_\(userId)"
    }
}
