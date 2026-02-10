import Foundation
import os

/// Protocol for recipe API operations - enables mocking in tests
protocol RecipeServiceProtocol: Sendable {
    func fetchRecipes() async throws -> [RecipeListItem]
    func fetchRecipeDetail(id: Int) async throws -> RecipeDetail
    func deleteRecipe(id: Int) async throws
}

/// Handles all recipe-related API calls
final class RecipeService: RecipeServiceProtocol, @unchecked Sendable {
    static let shared = RecipeService()

    private let api = APIClient.shared
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeService")

    private init() {}

    /// Fetches all recipes for the authenticated user
    func fetchRecipes() async throws -> [RecipeListItem] {
        self.logger.info("Fetching recipes from API")

        let recipes: [RecipeListItem] = try await api.request(
            endpoint: "recipes",
            method: .get,
            authenticated: true
        )

        self.logger.info("Fetched \(recipes.count) recipes from API")
        return recipes
    }

    /// Fetches full details for a single recipe
    func fetchRecipeDetail(id: Int) async throws -> RecipeDetail {
        self.logger.info("Fetching recipe detail for id: \(id)")

        let recipe: RecipeDetail = try await api.request(
            endpoint: "recipes/\(id)",
            method: .get,
            authenticated: true
        )

        self.logger.info("Fetched recipe detail: \(recipe.name)")
        return recipe
    }

    /// Deletes a recipe by ID
    func deleteRecipe(id: Int) async throws {
        self.logger.info("Deleting recipe with id: \(id)")

        do {
            try await self.api.requestVoid(
                endpoint: "recipes/\(id)",
                method: .delete,
                authenticated: true
            )
            self.logger.info("Deleted recipe with id: \(id)")
        } catch APIError.notFound {
            self.logger.info("Recipe \(id) already deleted on server")
        }
    }
}
