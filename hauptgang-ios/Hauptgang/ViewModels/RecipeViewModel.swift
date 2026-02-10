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
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeViewModel")

    /// Polling task for pending imports
    private var pollingTask: Task<Void, Never>?

    /// Polling configuration
    private let pollingInterval: UInt64 = 3_000_000_000 // 3 seconds in nanoseconds
    private let maxPollingDuration: UInt64 = 30_000_000_000 // 30 seconds in nanoseconds

    init(
        recipeService: RecipeServiceProtocol = RecipeService.shared,
        repository: RecipeRepositoryProtocol? = nil
    ) {
        self.recipeService = recipeService
        self.repository = repository ?? RecipeRepository()
    }

    /// Configure the view model with a model context for persistence
    func configure(modelContext: ModelContext) {
        self.logger.info("RecipeViewModel configuring with model context")
        self.repository.configure(modelContext: modelContext)

        // Load cached recipes immediately
        self.loadCachedRecipes()
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
            try self.repository.saveRecipes(apiRecipes)
            self.loadCachedRecipes()
            self.logger.info("Recipe refresh completed successfully")

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
        } catch {
            self.logger.error("Failed to clear recipe data: \(error.localizedDescription)")
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
}
