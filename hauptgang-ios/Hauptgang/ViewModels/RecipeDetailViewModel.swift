import Foundation
import os
import SwiftData

/// Manages state for the recipe detail view
@MainActor @Observable
final class RecipeDetailViewModel {
    private(set) var recipe: RecipeDetail?
    private(set) var isLoading = false
    private(set) var isRefreshing = false
    private(set) var isOffline = false
    private(set) var errorMessage: String?

    private let recipeService: RecipeServiceProtocol
    private let repository: RecipeRepositoryProtocol
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeDetailViewModel")
    private var currentLoadID: UUID?

    init(
        recipeService: RecipeServiceProtocol = RecipeService.shared,
        repository: RecipeRepositoryProtocol? = nil
    ) {
        self.recipeService = recipeService
        self.repository = repository ?? RecipeRepository()
    }

    /// Configure the repository with a model context
    func configure(modelContext: ModelContext) {
        repository.configure(modelContext: modelContext)
    }

    /// Load recipe details with cache-aside pattern
    func loadRecipe(id: Int) async {
        let loadID = UUID()
        currentLoadID = loadID

        logger.info("Loading recipe detail for id: \(id)")
        errorMessage = nil
        isOffline = false

        loadCachedRecipe(id: id)

        isLoading = (recipe == nil)
        isRefreshing = (recipe != nil)

        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let apiRecipe = try await recipeService.fetchRecipeDetail(id: id)

            guard currentLoadID == loadID else {
                logger.debug("Ignoring stale response for recipe id: \(id)")
                return
            }

            recipe = apiRecipe
            isOffline = false
            logger.info("Successfully loaded recipe from API: \(apiRecipe.name)")

            do {
                try repository.saveRecipeDetail(apiRecipe)
            } catch {
                logger.error("Failed to persist recipe detail: \(error.localizedDescription)")
            }
        } catch is CancellationError {
            logger.debug("Recipe load cancelled for id: \(id)")
            return
        } catch {
            guard currentLoadID == loadID else { return }

            logger.error("Failed to load recipe detail: \(error.localizedDescription)")
            if recipe != nil {
                isOffline = true
                logger.info("Showing cached recipe in offline mode")
            } else {
                errorMessage = "Failed to load recipe. Tap to retry."
            }
        }
    }

    /// Load cached recipe from local storage
    private func loadCachedRecipe(id: Int) {
        do {
            if let persisted = try repository.getRecipe(id: id),
               let cached = persisted.toRecipeDetail() {
                recipe = cached
                logger.info("Loaded cached recipe: \(cached.name)")
            }
        } catch {
            logger.error("Failed to load cached recipe: \(error.localizedDescription)")
        }
    }
}
