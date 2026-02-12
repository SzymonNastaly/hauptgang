import Foundation
import os
import SwiftData

/// Manages recipe state for the UI
@MainActor @Observable
final class RecipeViewModel {
    private(set) var recipes: [PersistedRecipe] = []
    private(set) var isLoading = false
    private(set) var isOffline = false
    private(set) var isImporting = false
    private(set) var searchResults: [PersistedRecipe] = []
    var importError: String?
    var shouldShowPaywall: Bool = false

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
    private var currentUserId: Int?

    /// Polling configuration
    private let pollingInterval: UInt64 = 3_000_000_000 // 3 seconds in nanoseconds
    private let maxPollingDuration: UInt64 = 30_000_000_000 // 30 seconds in nanoseconds

    /// Lightweight value snapshot for background search scoring
    private struct RecipeSnapshot: Sendable {
        let id: Int
        let name: String
        let ingredients: [String]
        let instructions: [String]
        let updatedAt: Date
    }

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

    /// Configure search indexing for the current user
    func configureSearchIndex(userId: Int) async {
        guard self.currentUserId != userId else { return }
        self.currentUserId = userId
        await self.searchIndex.configure(userId: userId)
    }

    /// Load recipes from local cache
    private func loadCachedRecipes() {
        do {
            self.recipes = try self.repository.getAllRecipes()
            self.logger.info("Loaded \(self.recipes.count) recipes from cache")
        } catch {
            self.logger.error("Failed to load cached recipes: \(error.localizedDescription)")
        }
    }

    /// Fetch fresh recipes from API and update local cache
    func refreshRecipes() async {
        guard !self.isLoading else {
            self.logger.info("Refresh already in progress, skipping")
            return
        }

        self.logger.info("Starting recipe refresh")
        self.isLoading = true
        self.isOffline = false

        do {
            let apiRecipes = try await recipeService.fetchRecipes()
            let deletedIds = try self.repository.saveRecipes(apiRecipes)
            self.loadCachedRecipes()
            self.logger.info("Recipe refresh completed successfully")

            let visibleRecipes = self.successfulRecipes
            if await self.searchIndex.needsRebuild() {
                let detailInputs = self.detailInputs(from: visibleRecipes)
                await self.searchIndex.rebuildIndex(with: detailInputs)
            } else {
                let nameInputs = self.nameInputs(from: visibleRecipes)
                await self.searchIndex.indexNames(nameInputs)
                if !deletedIds.isEmpty {
                    await self.searchIndex.delete(ids: deletedIds)
                }
            }

            self.startDetailSyncIfNeeded()

            // Start polling if there are pending imports
            if self.hasPendingImports {
                self.startPolling()
            }
        } catch {
            self.logger.error("Recipe refresh failed: \(error.localizedDescription)")
            if let apiError = error as? APIError, case .networkError = apiError {
                self.isOffline = true
            }
            // Keep showing cached data on error
        }

        self.isLoading = false
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
                let results = await self.fetchRecipesByIds(ids)
                self.searchResults = self.sortResults(results, by: ids)
                return
            }
        }

        // Cancel any previous background search
        self.searchTask?.cancel()

        // Snapshot recipe data for background scoring (PersistedRecipe is not Sendable)
        let snapshots = self.successfulRecipes.map {
            RecipeSnapshot(id: $0.id, name: $0.name, ingredients: $0.ingredients,
                           instructions: $0.instructions, updatedAt: $0.updatedAt)
        }
        let query = trimmed

        self.searchTask = Task.detached { [weak self] in
            let rankedIds = Self.backgroundSearch(query: query, snapshots: snapshots)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self?.applySearchResults(rankedIds: rankedIds)
            }
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

        self.pollingTask = Task.detached { [weak self] in
            guard let self else { return }

            defer {
                Task { @MainActor in
                    self.pollingTask = nil
                }
            }

            while !Task.isCancelled {
                let elapsed = DispatchTime.now().uptimeNanoseconds - startTime
                if elapsed > maxDuration {
                    await MainActor.run { self.logger.info("Polling timeout reached, stopping") }
                    break
                }

                do {
                    try await Task.sleep(nanoseconds: interval)
                } catch {
                    break
                }

                if Task.isCancelled { break }

                await MainActor.run { self.logger.info("Polling: refreshing recipes") }
                do {
                    let apiRecipes = try await self.recipeService.fetchRecipes()

                    let stillPending = await MainActor.run {
                        do {
                            try self.repository.saveRecipes(apiRecipes)
                            self.loadCachedRecipes()
                        } catch {
                            self.logger.error("Polling save failed: \(error.localizedDescription)")
                        }
                        return self.hasPendingImports
                    }

                    if !stillPending {
                        await MainActor.run { self.logger.info("No more pending imports, stopping polling") }
                        break
                    }
                } catch {
                    await MainActor.run { self.logger.error("Polling refresh failed: \(error.localizedDescription)") }
                }
            }
        }
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

        self.detailSyncTask?.cancel()
        self.detailSyncTask = nil
        self.clearDetailSyncCursor()
        Task {
            await self.searchIndex.reset()
        }
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
        }

        self.isImporting = false
    }

    /// Dismiss a failed recipe (optimistic delete)
    func dismissFailedRecipe(_ recipe: PersistedRecipe) async {
        let recipeId = recipe.id
        self.logger.info("Dismissing failed recipe: \(recipeId)")

        // Optimistic: delete from local cache immediately
        do {
            try self.repository.deleteRecipe(id: recipeId)
            self.loadCachedRecipes()
        } catch {
            self.logger.error("Failed to delete recipe locally: \(error.localizedDescription)")
        }

        // Background: delete from server
        do {
            try await self.recipeService.deleteRecipe(id: recipeId)
            self.logger.info("Deleted recipe from server: \(recipeId)")
        } catch {
            // Server delete failed, but local is already removed
            // Next refresh will re-sync if needed (or auto-cleanup handles it)
            self.logger.error("Failed to delete recipe from server: \(error.localizedDescription)")
        }
    }

    // MARK: - Detail Sync

    private func startDetailSyncIfNeeded() {
        guard self.detailSyncTask == nil else { return }
        guard let userId = self.currentUserId else { return }

        let recipeService = self.recipeService
        let repository = self.repository
        let searchIndex = self.searchIndex
        let cursorKey = self.detailCursorKey(for: userId)

        self.detailSyncTask = Task.detached(priority: .utility) { [weak self] in
            defer {
                Task { @MainActor in
                    self?.detailSyncTask = nil
                }
            }

            var cursor = UserDefaults.standard.string(forKey: cursorKey)

            while !Task.isCancelled {
                do {
                    let response = try await recipeService.fetchRecipeDetails(cursor: cursor, limit: 100)
                    if response.recipes.isEmpty { break }

                    await MainActor.run {
                        do {
                            try repository.saveRecipeDetails(response.recipes)
                        } catch {
                            self?.logger.error("Detail sync save failed: \(error.localizedDescription)")
                        }
                        self?.loadCachedRecipes()
                    }

                    let detailInputs = response.recipes.map {
                        SearchIndexDetailInput(
                            id: $0.id,
                            name: $0.name,
                            ingredients: $0.ingredients,
                            instructions: $0.instructions,
                            updatedAt: $0.updatedAt
                        )
                    }
                    await searchIndex.indexDetails(detailInputs)

                    if let nextCursor = response.nextCursor {
                        UserDefaults.standard.set(nextCursor, forKey: cursorKey)
                        cursor = nextCursor
                    } else {
                        UserDefaults.standard.removeObject(forKey: cursorKey)
                        break
                    }
                } catch {
                    self?.logger.error("Detail sync failed: \(error.localizedDescription)")
                    break
                }
            }
        }
    }

    private func detailCursorKey(for userId: Int) -> String {
        "recipe_detail_cursor.\(userId)"
    }

    private func clearDetailSyncCursor() {
        guard let userId = self.currentUserId else { return }
        UserDefaults.standard.removeObject(forKey: self.detailCursorKey(for: userId))
        self.currentUserId = nil
    }

    @MainActor
    private func fetchRecipesByIds(_ ids: [Int]) async -> [PersistedRecipe] {
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

    /// Perform fuzzy search scoring on background thread using value-type snapshots
    nonisolated private static func backgroundSearch(query: String, snapshots: [RecipeSnapshot]) -> [Int] {
        let queryTokenGroups = RecipeSearchQuery.expandedTokenVariants(from: query)
        guard !queryTokenGroups.isEmpty else { return [] }

        let scored: [(Int, Int, Date)] = snapshots.compactMap { snapshot in
            guard !Task.isCancelled else { return nil }

            let nameTokens = normalizedTokens(from: snapshot.name)
            let ingredientTokens = normalizedTokens(from: snapshot.ingredients.joined(separator: " "))
            let instructionTokens = normalizedTokens(from: snapshot.instructions.joined(separator: " "))

            var totalScore = 0
            for variants in queryTokenGroups {
                var bestScore = 0
                for variant in variants {
                    let nameScore = fuzzyVariantScore(tokens: variant, recipeTokens: nameTokens, weight: 5)
                    let ingredientScore = fuzzyVariantScore(tokens: variant, recipeTokens: ingredientTokens, weight: 3)
                    let instructionScore = fuzzyVariantScore(tokens: variant, recipeTokens: instructionTokens, weight: 1)
                    bestScore = max(bestScore, nameScore, ingredientScore, instructionScore)
                }

                if bestScore == 0 {
                    return nil
                }

                totalScore += bestScore
            }

            return totalScore > 0 ? (snapshot.id, totalScore, snapshot.updatedAt) : nil
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.2 > rhs.2
                }
                return lhs.1 > rhs.1
            }
            .map { $0.0 }
    }

    nonisolated private static func normalizedTokens(from string: String) -> [String] {
        RecipeSearchQuery.normalizedTokens(from: string)
    }

    nonisolated private static func fuzzyVariantScore(tokens: [String], recipeTokens: [String], weight: Int) -> Int {
        guard !tokens.isEmpty else { return 0 }
        var total = 0

        for token in tokens {
            let score = fuzzyMatchScore(queryToken: token, tokens: recipeTokens, weight: weight)
            if score == 0 {
                return 0
            }
            total += score
        }

        return total
    }

    nonisolated private static func fuzzyMatchScore(queryToken: String, tokens: [String], weight: Int) -> Int {
        guard !tokens.isEmpty else { return 0 }
        let maxDist = maxEditDistance(for: queryToken)

        for token in tokens {
            if token.contains(queryToken) {
                return weight * 2
            }

            if token.count >= queryToken.count {
                let prefix = String(token.prefix(queryToken.count))
                if levenshteinDistance(queryToken, prefix, maxDistance: maxDist) != nil {
                    return weight
                }
            }

            if levenshteinDistance(queryToken, token, maxDistance: maxDist) != nil {
                return weight
            }
        }
        return 0
    }

    nonisolated private static func maxEditDistance(for token: String) -> Int {
        switch token.count {
        case 0...4:
            0
        case 5...7:
            1
        default:
            2
        }
    }

    nonisolated private static func levenshteinDistance(_ lhs: String, _ rhs: String, maxDistance: Int) -> Int? {
        if lhs == rhs { return 0 }
        if abs(lhs.count - rhs.count) > maxDistance { return nil }

        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        if lhsChars.isEmpty { return rhsChars.count <= maxDistance ? rhsChars.count : nil }
        if rhsChars.isEmpty { return lhsChars.count <= maxDistance ? lhsChars.count : nil }

        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for i in 1...lhsChars.count {
            current[0] = i
            var rowMin = current[0]

            for j in 1...rhsChars.count {
                let cost = lhsChars[i - 1] == rhsChars[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
                rowMin = min(rowMin, current[j])
            }

            if rowMin > maxDistance {
                return nil
            }

            previous = current
        }

        let distance = previous[rhsChars.count]
        return distance <= maxDistance ? distance : nil
    }

    private func nameInputs(from recipes: [PersistedRecipe]) -> [SearchIndexNameInput] {
        recipes.map {
            SearchIndexNameInput(id: $0.id, name: $0.name, updatedAt: $0.updatedAt)
        }
    }

    private func detailInputs(from recipes: [PersistedRecipe]) -> [SearchIndexDetailInput] {
        recipes.map {
            SearchIndexDetailInput(
                id: $0.id,
                name: $0.name,
                ingredients: $0.ingredients,
                instructions: $0.instructions,
                updatedAt: $0.updatedAt
            )
        }
    }
}
