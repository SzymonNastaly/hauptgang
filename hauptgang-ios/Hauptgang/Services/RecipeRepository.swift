import Foundation
import os
import SwiftData

/// Errors that can occur in the recipe repository
enum RepositoryError: Error, LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Repository not configured with model context"
        }
    }
}

/// Protocol for recipe persistence - enables mocking in tests
@MainActor
protocol RecipeRepositoryProtocol {
    func configure(modelContext: ModelContext)
    func saveRecipes(_ recipes: [RecipeListItem]) throws
    func getAllRecipes() throws -> [PersistedRecipe]
    func clearAllRecipes() throws
    func getRecipe(id: Int) throws -> PersistedRecipe?
    func saveRecipeDetail(_ detail: RecipeDetail) throws
}

/// Handles local persistence of recipes using SwiftData
@MainActor
final class RecipeRepository: RecipeRepositoryProtocol {
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
            throw RepositoryError.notConfigured
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

    /// Retrieve all cached recipes, sorted by most recent update
    func getAllRecipes() throws -> [PersistedRecipe] {
        guard let modelContext else {
            logger.error("Attempted to fetch recipes without model context")
            throw RepositoryError.notConfigured
        }

        let descriptor = FetchDescriptor<PersistedRecipe>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        let recipes = try modelContext.fetch(descriptor)
        logger.info("Loaded \(recipes.count) cached recipes")
        return recipes
    }

    /// Clear all cached recipes (used on logout)
    func clearAllRecipes() throws {
        guard let modelContext else {
            logger.error("Attempted to clear recipes without model context")
            throw RepositoryError.notConfigured
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

    /// Get cached recipe by ID
    func getRecipe(id: Int) throws -> PersistedRecipe? {
        guard let modelContext else {
            logger.error("Attempted to fetch recipe without model context")
            throw RepositoryError.notConfigured
        }

        let descriptor = FetchDescriptor<PersistedRecipe>(
            predicate: #Predicate { $0.id == id }
        )

        return try modelContext.fetch(descriptor).first
    }

    /// Save full recipe detail from API
    func saveRecipeDetail(_ detail: RecipeDetail) throws {
        guard let modelContext else {
            logger.error("Attempted to save recipe detail without model context")
            throw RepositoryError.notConfigured
        }

        logger.info("Saving recipe detail for id: \(detail.id)")

        let descriptor = FetchDescriptor<PersistedRecipe>(
            predicate: #Predicate { $0.id == detail.id }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: detail)
        } else {
            let newRecipe = PersistedRecipe(from: detail)
            modelContext.insert(newRecipe)
        }

        try modelContext.save()
        logger.info("Successfully saved recipe detail for: \(detail.name)")
    }
}
