import Foundation
import os
import Sentry
import SwiftData
import SwiftUI

/// Manages recipe state for the UI
@MainActor @Observable
final class RecipeViewModel {
    private(set) var recipes: [PersistedRecipe] = []
    private(set) var isLoading = false
    private(set) var isOffline = false
    private(set) var isImporting = false
    private(set) var searchResults: [PersistedRecipe] = []
    private(set) var pendingDeletionIDs: Set<Int> = []
    var importError: String?
    var shouldShowPaywall: Bool = false
    var didReceiveForbidden = false
    private var reportedFailedRecipeIds: Set<Int> = []

    /// Whether any recipes are currently being imported
    var hasPendingImports: Bool {
        self.recipes.contains { $0.importStatus == "pending" }
    }

    /// Failed recipes for display as error banners
    var failedRecipes: [PersistedRecipe] {
        self.recipes.filter { $0.importStatus == "failed" }
    }

    /// Successful recipes (excluding failed ones)
    var successfulRecipes: [PersistedRecipe] {
        self.recipes.filter { $0.importStatus != "failed" }
    }

    private let repository: RecipeRepositoryProtocol
    private let recipeService: RecipeServiceProtocol
    private let searchIndex: RecipeSearchIndexProtocol
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeViewModel")

    /// Polling task for pending imports
    private var pollingTask: Task<Void, Never>?
    private var detailSyncTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var currentUserId: Int?
    private var currentCookbookId: Int?

    /// Polling configuration
    private let pollingInterval: UInt64 = 3_000_000_000 // 3 seconds in nanoseconds
    private let maxPollingDuration: UInt64 = 30_000_000_000 // 30 seconds in nanoseconds

    init(
        recipeService: RecipeServiceProtocol = RecipeService.shared,
        repository: RecipeRepositoryProtocol? = nil,
        searchIndex: RecipeSearchIndexProtocol = RecipeSearchIndex.shared
    ) {
        self.recipeService = recipeService
        self.repository = repository ?? RecipeRepository()
        self.searchIndex = searchIndex
    }

    /// Configure the view model with a model context for persistence
    func configure(modelContext: ModelContext) {
        self.logger.info("RecipeViewModel configuring with model context")
        self.repository.configure(modelContext: modelContext)

        // Load cached recipes immediately
        self.loadCachedRecipes()
    }

    /// Configure search indexing for the current user and cookbook
    func configureSearchIndex(userId: Int, cookbookId: Int = 0) async {
        self.currentUserId = userId
        self.currentCookbookId = cookbookId
        self.loadCachedRecipes()
        await self.searchIndex.configure(userId: userId, cookbookId: cookbookId)
    }
}

extension RecipeViewModel {
    /// Load recipes from local cache for the active cookbook, filtering out pending deletions
    private func loadCachedRecipes() {
        do {
            let all = try self.repository.getAllRecipes(cookbookId: self.currentCookbookId)
            self.recipes = self.pendingDeletionIDs.isEmpty
                ? all
                : all.filter { !self.pendingDeletionIDs.contains($0.id) }
            self.logger.info("Loaded \(self.recipes.count) recipes from cache")
            self.reportNewlyFailedRecipes()
        } catch {
            self.logger.error("Failed to load cached recipes: \(error.localizedDescription)")
        }
    }

    /// Report any newly-failed recipe imports to Sentry (deduplicated by recipe ID)
    private func reportNewlyFailedRecipes() {
        for recipe in self.failedRecipes where !self.reportedFailedRecipeIds.contains(recipe.id) {
            self.reportedFailedRecipeIds.insert(recipe.id)
            let event = Event(level: .error)
            event.message = SentryMessage(formatted: "Recipe import failed")
            event.extra = [
                "recipe_id": recipe.id,
                "recipe_name": recipe.name,
                "error_message": recipe.errorMessage ?? "unknown",
                "source_url": recipe.sourceUrl ?? "unknown",
                "import_status": recipe.importStatus ?? "unknown",
                "cookbook_id": recipe.cookbookId,
            ]
            SentrySDK.capture(event: event)
        }
    }

    /// Fetch fresh recipes from API and update local cache.
    ///
    /// Cancels any in-flight refresh so the latest caller always wins. This avoids a race where
    /// a slow/failing background refresh (e.g. from scenePhase) blocks a user-initiated
    /// pull-to-refresh, leaving the offline toast stuck.
    func refreshRecipes() async {
        self.refreshTask?.cancel()
        self.refreshTask = nil

        self.logger.info("Starting recipe refresh")
        self.isLoading = true
        self.isOffline = false

        let task = Task { @MainActor in
            await self.performRefresh()
        }

        self.refreshTask = task
        await task.value

        // Only clear isLoading if this task wasn't superseded
        if self.refreshTask == task {
            self.isLoading = false
            self.refreshTask = nil
        }
    }

    private func performRefresh() async {
        do {
            try await self.fetchAndPersistRecipes()
            self.logger.info("Recipe refresh completed successfully")
        } catch is CancellationError {
            self.logger.info("Recipe refresh cancelled by newer request")
        } catch {
            guard !Task.isCancelled else {
                self.logger.info("Recipe refresh cancelled by newer request")
                return
            }
            self.handleRefreshError(error)
        }
    }

    private func fetchAndPersistRecipes() async throws {
        let apiRecipes = try await self.recipeService.fetchRecipes()
        try Task.checkCancellation()

        let deletedIds = try self.repository.saveRecipes(apiRecipes, cookbookId: self.currentCookbookId)
        self.loadCachedRecipes()

        let visibleRecipes = self.successfulRecipes
        await self.updateSearchIndex(visibleRecipes: visibleRecipes, deletedIds: deletedIds)
        self.startDetailSyncIfNeeded()

        if self.hasPendingImports {
            self.startPolling()
        }
    }

    private func updateSearchIndex(visibleRecipes: [PersistedRecipe], deletedIds: [Int]) async {
        if await self.searchIndex.needsRebuild() {
            await self.searchIndex.rebuildIndex(with: self.detailInputs(from: visibleRecipes))
            return
        }

        await self.searchIndex.indexNames(self.nameInputs(from: visibleRecipes))
        if !deletedIds.isEmpty {
            await self.searchIndex.delete(ids: deletedIds)
        }
    }

    private func handleRefreshError(_ error: Error) {
        self.logger.error("Recipe refresh failed: \(error.localizedDescription)")

        guard let apiError = error as? APIError else {
            return
        }

        switch apiError {
        case .networkError:
            self.isOffline = true
        case .forbidden:
            self.didReceiveForbidden = true
        default:
            break
        }
    }

    /// Search locally indexed recipes with ranked results
    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.searchResults = []
            return
        }

        if await self.searchIndex.isAvailable() {
            let ids = await self.searchIndex.search(trimmed, limit: 50)
            if !ids.isEmpty {
                let results = self.fetchRecipesByIds(ids)
                self.searchResults = self.sortResults(results, by: ids)
                return
            }
        }

        // Cancel any previous background search
        self.searchTask?.cancel()

        // Snapshot recipe data for background scoring (PersistedRecipe is not Sendable)
        let snapshots = self.successfulRecipes.map {
            RecipeSearchSnapshot(
                id: $0.id,
                name: $0.name,
                ingredients: $0.ingredients,
                instructions: $0.instructions,
                updatedAt: $0.updatedAt
            )
        }
        let query = trimmed

        self.searchTask = Task { [weak self, snapshots, query] in
            let rankedIds = await Task.detached(priority: .utility) {
                RecipeFuzzyScorer.rankedIds(query: query, snapshots: snapshots)
            }.value

            guard !Task.isCancelled else { return }
            self?.applySearchResults(rankedIds: rankedIds)
        }
    }

    /// Apply background search results by mapping ranked IDs back to model objects
    private func applySearchResults(rankedIds: [Int]) {
        let byId = Dictionary(uniqueKeysWithValues: self.successfulRecipes.map { ($0.id, $0) })
        self.searchResults = rankedIds.compactMap { byId[$0] }
    }

    // MARK: - Polling for Pending Imports

    /// Start polling for pending import status updates
    private func startPolling() {
        self.pollingTask?.cancel()

        self.logger.info("Starting polling for pending imports")
        let startTime = DispatchTime.now().uptimeNanoseconds
        let maxDuration = self.maxPollingDuration
        let interval = self.pollingInterval

        self.pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.runPollingLoop(startTime: startTime, maxDuration: maxDuration, interval: interval)
            self.pollingTask = nil
        }
    }

    private func runPollingLoop(startTime: UInt64, maxDuration: UInt64, interval: UInt64) async {
        while !Task.isCancelled {
            if self.pollingTimedOut(startTime: startTime, maxDuration: maxDuration) {
                await MainActor.run {
                    self.logger.info("Polling timeout reached, stopping")
                }
                break
            }

            do {
                try await Task.sleep(nanoseconds: interval)
            } catch {
                break
            }

            if Task.isCancelled { break }
            if await self.pollOnceFoundNoPendingImports() {
                await MainActor.run {
                    self.logger.info("No more pending imports, stopping polling")
                }
                break
            }
        }
    }

    private func pollingTimedOut(startTime: UInt64, maxDuration: UInt64) -> Bool {
        let elapsed = DispatchTime.now().uptimeNanoseconds - startTime
        return elapsed > maxDuration
    }

    private func pollOnceFoundNoPendingImports() async -> Bool {
        await MainActor.run {
            self.logger.info("Polling: refreshing recipes")
        }

        do {
            let apiRecipes = try await self.recipeService.fetchRecipes()
            let stillPending = await MainActor.run {
                self.applyPollingRecipes(apiRecipes)
            }
            return !stillPending
        } catch {
            await MainActor.run {
                self.logger.error("Polling refresh failed: \(error.localizedDescription)")
            }
            return false
        }
    }

    private func applyPollingRecipes(_ apiRecipes: [RecipeListItem]) -> Bool {
        do {
            _ = try self.repository.saveRecipes(apiRecipes, cookbookId: self.currentCookbookId)
            self.loadCachedRecipes()
        } catch {
            self.logger.error("Polling save failed: \(error.localizedDescription)")
        }
        return self.hasPendingImports
    }

    /// Cancel all in-flight tasks and clear data for a cookbook switch
    func resetForCookbookSwitch() {
        self.refreshTask?.cancel()
        self.refreshTask = nil
        self.pollingTask?.cancel()
        self.pollingTask = nil
        self.detailSyncTask?.cancel()
        self.detailSyncTask = nil
        self.searchTask?.cancel()
        self.searchTask = nil
        self.recipes = []
        self.searchResults = []
        self.isLoading = false
        self.isOffline = false
    }

    /// Stop polling for pending imports
    func stopPolling() {
        self.logger.info("Stopping polling")
        self.pollingTask?.cancel()
        self.pollingTask = nil
    }

    /// Clear all recipe data (call on logout)
    func clearData() {
        self.logger.info("Clearing recipe data")
        do {
            try self.repository.clearAllRecipes()
            self.recipes = []
            self.searchResults = []
        } catch {
            self.logger.error("Failed to clear recipe data: \(error.localizedDescription)")
        }

        self.refreshTask?.cancel()
        self.refreshTask = nil
        self.detailSyncTask?.cancel()
        self.detailSyncTask = nil
        self.clearDetailSyncCursor()
        Task {
            await self.searchIndex.reset()
        }
    }

    /// Import a recipe from pasted text
    func importRecipeFromText(_ text: String) async {
        self.isImporting = true
        self.importError = nil

        do {
            _ = try await RecipeImportService.shared.importRecipe(fromText: text)
            await self.refreshRecipes()
        } catch APIError.importLimitReached {
            self.shouldShowPaywall = true
            self.logger.info("Import limit reached, showing paywall")
        } catch {
            if let apiError = error as? APIError {
                self.importError = apiError.errorDescription ?? "Failed to import recipe from text."
            } else {
                self.importError = "Failed to import recipe from text."
            }
            self.logger.error("Text import failed: \(error.localizedDescription)")
            SentrySDK.capture(error: error) { scope in
                scope.setContext(value: [
                    "source": "text_import",
                    "error_description": self.importError ?? "unknown",
                ], key: "import")
            }
        }

        self.isImporting = false
    }

    /// Import a recipe from image data (compress, upload, refresh)
    func importRecipeFromImage(_ imageData: Data) async {
        self.isImporting = true
        self.importError = nil

        let compressed = await Task.detached {
            ImageCompressor.compressToJPEG(imageData)
        }.value

        guard let compressed else {
            self.importError = "Could not process image. Please try a different photo."
            self.isImporting = false
            return
        }

        do {
            _ = try await RecipeImportService.shared.importRecipe(from: compressed)
            await self.refreshRecipes()
        } catch APIError.importLimitReached {
            self.shouldShowPaywall = true
            self.logger.info("Import limit reached, showing paywall")
        } catch {
            if let apiError = error as? APIError {
                self.importError = apiError.errorDescription ?? "Failed to import recipe from photo."
            } else {
                self.importError = "Failed to import recipe from photo."
            }
            self.logger.error("Image import failed: \(error.localizedDescription)")
            SentrySDK.capture(error: error) { scope in
                scope.setContext(value: [
                    "source": "image_import",
                    "error_description": self.importError ?? "unknown",
                ], key: "import")
            }
        }

        self.isImporting = false
    }

    /// Dismiss a failed recipe (optimistic delete)
    func dismissFailedRecipe(_ recipe: PersistedRecipe) async {
        await self.deleteRecipe(id: recipe.id)
    }

    /// Delete a recipe (optimistic local delete + background server delete)
    func deleteRecipe(id recipeId: Int) async {
        self.logger.info("Deleting recipe: \(recipeId)")
        self.pendingDeletionIDs.insert(recipeId)

        do {
            try self.repository.deleteRecipe(id: recipeId)
            withAnimation {
                self.loadCachedRecipes()
                self.searchResults.removeAll { $0.id == recipeId }
            }
        } catch {
            self.logger.error("Failed to delete recipe locally: \(error.localizedDescription)")
        }

        await self.searchIndex.delete(ids: [recipeId])

        do {
            try await self.recipeService.deleteRecipe(id: recipeId)
            self.logger.info("Deleted recipe from server: \(recipeId)")
        } catch {
            self.logger.error("Failed to delete recipe from server: \(error.localizedDescription)")
        }

        self.pendingDeletionIDs.remove(recipeId)
    }

    // MARK: - Detail Sync

    private func startDetailSyncIfNeeded() {
        guard self.detailSyncTask == nil else { return }
        guard let userId = self.currentUserId else { return }

        let recipeService = self.recipeService
        let repository = self.repository
        let searchIndex = self.searchIndex
        let cursorKey = self.detailCursorKey(for: userId)

        self.detailSyncTask = Task(priority: .utility) { [weak self] in
            await self?.runDetailSyncLoop(
                recipeService: recipeService,
                repository: repository,
                searchIndex: searchIndex,
                cursorKey: cursorKey
            )
            self?.detailSyncTask = nil
        }
    }

    private func runDetailSyncLoop(
        recipeService: RecipeServiceProtocol,
        repository: RecipeRepositoryProtocol,
        searchIndex: RecipeSearchIndexProtocol,
        cursorKey: String
    ) async {
        var cursor = UserDefaults.standard.string(forKey: cursorKey)

        while !Task.isCancelled {
            do {
                let response = try await recipeService.fetchRecipeDetails(cursor: cursor, limit: 100)
                if response.recipes.isEmpty { break }

                await MainActor.run {
                    self.applyDetailSyncRecipes(response.recipes, repository: repository)
                }
                await searchIndex.indexDetails(self.detailInputs(from: response.recipes))

                if let nextCursor = response.nextCursor {
                    UserDefaults.standard.set(nextCursor, forKey: cursorKey)
                    cursor = nextCursor
                } else {
                    UserDefaults.standard.removeObject(forKey: cursorKey)
                    break
                }
            } catch {
                self.logger.error("Detail sync failed: \(error.localizedDescription)")
                break
            }
        }
    }

    private func applyDetailSyncRecipes(_ recipes: [RecipeDetail], repository: RecipeRepositoryProtocol) {
        do {
            try repository.saveRecipeDetails(recipes, cookbookId: self.currentCookbookId)
        } catch {
            self.logger.error("Detail sync save failed: \(error.localizedDescription)")
        }
        self.loadCachedRecipes()
    }

    private func detailCursorKey(for userId: Int) -> String {
        let cookbookId = self.currentCookbookId ?? 0
        return "recipe_detail_cursor.\(userId).\(cookbookId)"
    }

    private func clearDetailSyncCursor() {
        guard let userId = self.currentUserId else { return }
        UserDefaults.standard.removeObject(forKey: self.detailCursorKey(for: userId))
        self.currentUserId = nil
    }

    @MainActor
    private func fetchRecipesByIds(_ ids: [Int]) -> [PersistedRecipe] {
        do {
            return try self.repository.getRecipes(ids: ids)
        } catch {
            self.logger.error("Failed to fetch recipes by ids: \(error.localizedDescription)")
            return []
        }
    }

    private func sortResults(_ recipes: [PersistedRecipe], by ids: [Int]) -> [PersistedRecipe] {
        let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
        return recipes.sorted { lhs, rhs in
            let left = order[lhs.id] ?? Int.max
            let right = order[rhs.id] ?? Int.max
            if left == right {
                return lhs.updatedAt > rhs.updatedAt
            }
            return left < right
        }
    }
}
