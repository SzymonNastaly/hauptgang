import Foundation
import os
import SwiftData

/// Manages recipe state for the UI
@MainActor @Observable
final class RecipeViewModel {
    private(set) var recipes: [PersistedRecipe] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Whether any recipes are currently being imported
    var hasPendingImports: Bool {
        recipes.contains { $0.importStatus == "pending" }
    }

    /// Failed recipes for display as error banners
    var failedRecipes: [PersistedRecipe] {
        recipes.filter { $0.importStatus == "failed" }
    }

    /// Successful recipes (excluding failed ones)
    var successfulRecipes: [PersistedRecipe] {
        recipes.filter { $0.importStatus != "failed" }
    }

    private let repository: RecipeRepositoryProtocol
    private let recipeService: RecipeServiceProtocol
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeViewModel")

    /// Polling task for pending imports
    private var pollingTask: Task<Void, Never>?

    /// Polling configuration
    private let pollingInterval: UInt64 = 3_000_000_000  // 3 seconds in nanoseconds
    private let maxPollingDuration: UInt64 = 30_000_000_000  // 30 seconds in nanoseconds

    init(
        recipeService: RecipeServiceProtocol = RecipeService.shared,
        repository: RecipeRepositoryProtocol? = nil
    ) {
        self.recipeService = recipeService
        self.repository = repository ?? RecipeRepository()
    }

    /// Configure the view model with a model context for persistence
    func configure(modelContext: ModelContext) {
        logger.info("RecipeViewModel configuring with model context")
        repository.configure(modelContext: modelContext)

        // Load cached recipes immediately
        loadCachedRecipes()
    }

    /// Load recipes from local cache
    private func loadCachedRecipes() {
        do {
            recipes = try repository.getAllRecipes()
            logger.info("Loaded \(self.recipes.count) recipes from cache")
        } catch {
            logger.error("Failed to load cached recipes: \(error.localizedDescription)")
        }
    }

    /// Fetch fresh recipes from API and update local cache
    func refreshRecipes() async {
        guard !isLoading else {
            logger.info("Refresh already in progress, skipping")
            return
        }

        logger.info("Starting recipe refresh")
        isLoading = true
        errorMessage = nil

        do {
            let apiRecipes = try await recipeService.fetchRecipes()
            try repository.saveRecipes(apiRecipes)
            loadCachedRecipes()
            logger.info("Recipe refresh completed successfully")

            // Start polling if there are pending imports
            if hasPendingImports {
                startPolling()
            }
        } catch {
            logger.error("Recipe refresh failed: \(error.localizedDescription)")
            errorMessage = "Failed to load recipes. Pull to retry."
            // Keep showing cached data on error
        }

        isLoading = false
    }

    // MARK: - Polling for Pending Imports

    /// Start polling for pending import status updates
    private func startPolling() {
        pollingTask?.cancel()

        logger.info("Starting polling for pending imports")
        let startTime = DispatchTime.now().uptimeNanoseconds
        let maxDuration = maxPollingDuration
        let interval = pollingInterval

        pollingTask = Task.detached { [weak self] in
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
        logger.info("Stopping polling")
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Clear all recipe data (call on logout)
    func clearData() {
        logger.info("Clearing recipe data")
        do {
            try repository.clearAllRecipes()
            recipes = []
        } catch {
            logger.error("Failed to clear recipe data: \(error.localizedDescription)")
        }
    }

    /// Dismiss a failed recipe (optimistic delete)
    func dismissFailedRecipe(_ recipe: PersistedRecipe) async {
        let recipeId = recipe.id
        logger.info("Dismissing failed recipe: \(recipeId)")

        // Optimistic: delete from local cache immediately
        do {
            try repository.deleteRecipe(id: recipeId)
            loadCachedRecipes()
        } catch {
            logger.error("Failed to delete recipe locally: \(error.localizedDescription)")
        }

        // Background: delete from server
        do {
            try await recipeService.deleteRecipe(id: recipeId)
            logger.info("Deleted recipe from server: \(recipeId)")
        } catch {
            // Server delete failed, but local is already removed
            // Next refresh will re-sync if needed (or auto-cleanup handles it)
            logger.error("Failed to delete recipe from server: \(error.localizedDescription)")
        }
    }
}
