import Foundation
import os
import SwiftData

/// Manages recipe state for the UI
@MainActor @Observable
final class RecipeViewModel {
    private(set) var recipes: [PersistedRecipe] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository = RecipeRepository()
    private let recipeService: RecipeServiceProtocol
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeViewModel")

    init(recipeService: RecipeServiceProtocol = RecipeService.shared) {
        self.recipeService = recipeService
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
        logger.info("Starting recipe refresh")
        isLoading = true
        errorMessage = nil

        do {
            let apiRecipes = try await recipeService.fetchRecipes()
            try repository.saveRecipes(apiRecipes)
            loadCachedRecipes()
            logger.info("Recipe refresh completed successfully")
        } catch {
            logger.error("Recipe refresh failed: \(error.localizedDescription)")
            errorMessage = "Failed to load recipes. Pull to retry."
            // Keep showing cached data on error
        }

        isLoading = false
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
}
