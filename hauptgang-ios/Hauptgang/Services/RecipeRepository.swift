import Foundation
import os
import SwiftData

/// Errors that can occur in the recipe repository
enum RepositoryError: Error, LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Repository not configured with model context"
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
    func deleteRecipe(id: Int) throws
}

/// Handles local persistence of recipes using SwiftData
@MainActor
final class RecipeRepository: RecipeRepositoryProtocol {
    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeRepository")

    /// Configure the repository with a model context
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.logger.info("RecipeRepository configured with model context")
    }

    /// Save recipes from API response, updating existing or inserting new, and removing stale entries
    func saveRecipes(_ recipes: [RecipeListItem]) throws {
        guard let modelContext else {
            self.logger.error("Attempted to save recipes without model context")
            throw RepositoryError.notConfigured
        }

        self.logger.info("Syncing \(recipes.count) recipes to local storage")

        let apiRecipeIds = Set(recipes.map(\.id))

        // Remove recipes that are no longer in the API response
        let allLocalDescriptor = FetchDescriptor<PersistedRecipe>()
        let allLocal = try modelContext.fetch(allLocalDescriptor)
        for localRecipe in allLocal where !apiRecipeIds.contains(localRecipe.id) {
            logger.info("Removing stale recipe: \(localRecipe.id)")
            modelContext.delete(localRecipe)
        }

        // Add or update recipes from API
        for apiRecipe in recipes {
            let descriptor = FetchDescriptor<PersistedRecipe>(
                predicate: #Predicate { $0.id == apiRecipe.id }
            )

            if let existing = try modelContext.fetch(descriptor).first {
                existing.update(from: apiRecipe)
            } else {
                let newRecipe = PersistedRecipe(from: apiRecipe)
                modelContext.insert(newRecipe)
            }
        }

        try modelContext.save()
        self.logger.info("Successfully synced \(recipes.count) recipes")
    }

    /// Retrieve all cached recipes, sorted by most recent update
    func getAllRecipes() throws -> [PersistedRecipe] {
        guard let modelContext else {
            self.logger.error("Attempted to fetch recipes without model context")
            throw RepositoryError.notConfigured
        }

        let descriptor = FetchDescriptor<PersistedRecipe>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        let recipes = try modelContext.fetch(descriptor)
        self.logger.info("Loaded \(recipes.count) cached recipes")
        return recipes
    }

    /// Clear all cached recipes (used on logout)
    func clearAllRecipes() throws {
        guard let modelContext else {
            self.logger.error("Attempted to clear recipes without model context")
            throw RepositoryError.notConfigured
        }

        self.logger.info("Clearing all cached recipes")

        let descriptor = FetchDescriptor<PersistedRecipe>()
        let recipes = try modelContext.fetch(descriptor)

        for recipe in recipes {
            modelContext.delete(recipe)
        }

        try modelContext.save()
        self.logger.info("Cleared \(recipes.count) recipes from local storage")
    }

    /// Get cached recipe by ID
    func getRecipe(id: Int) throws -> PersistedRecipe? {
        guard let modelContext else {
            self.logger.error("Attempted to fetch recipe without model context")
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
            self.logger.error("Attempted to save recipe detail without model context")
            throw RepositoryError.notConfigured
        }

        self.logger.info("Saving recipe detail for id: \(detail.id)")

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
        self.logger.info("Successfully saved recipe detail for: \(detail.name)")
    }

    /// Delete a recipe by ID from local cache
    func deleteRecipe(id: Int) throws {
        guard let modelContext else {
            self.logger.error("Attempted to delete recipe without model context")
            throw RepositoryError.notConfigured
        }

        self.logger.info("Deleting recipe with id: \(id)")

        let descriptor = FetchDescriptor<PersistedRecipe>(
            predicate: #Predicate { $0.id == id }
        )

        if let recipe = try modelContext.fetch(descriptor).first {
            modelContext.delete(recipe)
            try modelContext.save()
            self.logger.info("Deleted recipe with id: \(id)")
        }
    }
}
