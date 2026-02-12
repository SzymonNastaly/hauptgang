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
    func saveRecipes(_ recipes: [RecipeListItem]) throws -> [Int]
    func getAllRecipes() throws -> [PersistedRecipe]
    func getRecipes(ids: [Int]) throws -> [PersistedRecipe]
    func clearAllRecipes() throws
    func getRecipe(id: Int) throws -> PersistedRecipe?
    func saveRecipeDetail(_ detail: RecipeDetail) throws
    func saveRecipeDetails(_ details: [RecipeDetail]) throws
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
    func saveRecipes(_ recipes: [RecipeListItem]) throws -> [Int] {
        guard let modelContext else {
            self.logger.error("Attempted to save recipes without model context")
            throw RepositoryError.notConfigured
        }

        self.logger.info("Syncing \(recipes.count) recipes to local storage")

        let apiRecipeIds = Set(recipes.map(\.id))

        // Remove stale recipes not in the API response (fetch only stale ones, not all)
        let staleDescriptor = FetchDescriptor<PersistedRecipe>(
            predicate: #Predicate { !apiRecipeIds.contains($0.id) }
        )
        let staleRecipes = try modelContext.fetch(staleDescriptor)
        let deletedIds = staleRecipes.map(\.id)
        for staleRecipe in staleRecipes {
            logger.info("Removing stale recipe: \(staleRecipe.id)")
            modelContext.delete(staleRecipe)
        }

        // Add or update recipes from API (batch fetch to avoid N+1)
        let apiIds = recipes.map(\.id)
        let existingDescriptor = FetchDescriptor<PersistedRecipe>(
            predicate: #Predicate { apiIds.contains($0.id) }
        )
        let existingRecipes = try modelContext.fetch(existingDescriptor)
        let existingById = Dictionary(uniqueKeysWithValues: existingRecipes.map { ($0.id, $0) })

        for apiRecipe in recipes {
            if let existing = existingById[apiRecipe.id] {
                existing.update(from: apiRecipe)
            } else {
                modelContext.insert(PersistedRecipe(from: apiRecipe))
            }
        }

        try modelContext.save()
        self.logger.info("Successfully synced \(recipes.count) recipes")
        return deletedIds
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

    /// Retrieve cached recipes by IDs
    func getRecipes(ids: [Int]) throws -> [PersistedRecipe] {
        guard let modelContext else {
            self.logger.error("Attempted to fetch recipes without model context")
            throw RepositoryError.notConfigured
        }

        guard !ids.isEmpty else { return [] }
        let ids = ids
        let descriptor = FetchDescriptor<PersistedRecipe>(
            predicate: #Predicate { ids.contains($0.id) }
        )

        let recipes = try modelContext.fetch(descriptor)
        self.logger.info("Loaded \(recipes.count) cached recipes by id")
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

    /// Save full recipe details from API in bulk
    func saveRecipeDetails(_ details: [RecipeDetail]) throws {
        guard let modelContext else {
            self.logger.error("Attempted to save recipe details without model context")
            throw RepositoryError.notConfigured
        }

        guard !details.isEmpty else { return }
        self.logger.info("Saving \(details.count) recipe details in bulk")

        // Batch fetch existing recipes to avoid N+1
        let detailIds = details.map(\.id)
        let existingDescriptor = FetchDescriptor<PersistedRecipe>(
            predicate: #Predicate { detailIds.contains($0.id) }
        )
        let existingRecipes = try modelContext.fetch(existingDescriptor)
        let existingById = Dictionary(uniqueKeysWithValues: existingRecipes.map { ($0.id, $0) })

        for detail in details {
            if let existing = existingById[detail.id] {
                existing.update(from: detail)
            } else {
                modelContext.insert(PersistedRecipe(from: detail))
            }
        }

        try modelContext.save()
        self.logger.info("Successfully saved \(details.count) recipe details")
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
