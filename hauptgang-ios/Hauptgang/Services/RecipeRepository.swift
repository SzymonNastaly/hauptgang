import Foundation
import os
import SwiftData

/// Handles local persistence of recipes using SwiftData
@MainActor
final class RecipeRepository {
    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeRepository")

    /// Configure the repository with a model context
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.info("RecipeRepository configured with model context")
    }

    /// Save recipes from API response, updating existing or inserting new
    func saveRecipes(_ recipes: [RecipeListItem]) throws {
        guard let modelContext else {
            logger.error("Attempted to save recipes without model context")
            return
        }

        logger.info("Saving \(recipes.count) recipes to local storage")

        for apiRecipe in recipes {
            // Check if recipe already exists
            let descriptor = FetchDescriptor<PersistedRecipe>(
                predicate: #Predicate { $0.id == apiRecipe.id }
            )

            if let existing = try modelContext.fetch(descriptor).first {
                // Update existing recipe
                existing.update(from: apiRecipe)
            } else {
                // Insert new recipe
                let newRecipe = PersistedRecipe(from: apiRecipe)
                modelContext.insert(newRecipe)
            }
        }

        try modelContext.save()
        logger.info("Successfully saved \(recipes.count) recipes")
    }

    /// Retrieve all cached recipes, sorted by name
    func getAllRecipes() throws -> [PersistedRecipe] {
        guard let modelContext else {
            logger.error("Attempted to fetch recipes without model context")
            return []
        }

        let descriptor = FetchDescriptor<PersistedRecipe>(
            sortBy: [SortDescriptor(\.name)]
        )

        let recipes = try modelContext.fetch(descriptor)
        logger.info("Loaded \(recipes.count) cached recipes")
        return recipes
    }

    /// Clear all cached recipes (used on logout)
    func clearAllRecipes() throws {
        guard let modelContext else {
            logger.error("Attempted to clear recipes without model context")
            return
        }

        logger.info("Clearing all cached recipes")

        let descriptor = FetchDescriptor<PersistedRecipe>()
        let recipes = try modelContext.fetch(descriptor)

        for recipe in recipes {
            modelContext.delete(recipe)
        }

        try modelContext.save()
        logger.info("Cleared \(recipes.count) recipes from local storage")
    }
}
