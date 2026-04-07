import Foundation
import os

/// Protocol for recipe API operations - enables mocking in tests
protocol RecipeServiceProtocol: Sendable {
    func fetchRecipes() async throws -> [RecipeListItem]
    func fetchRecipeDetail(id: Int) async throws -> RecipeDetail
    func fetchRecipeDetails(cursor: String?, limit: Int) async throws -> RecipeDetailBatchResponse
    func deleteRecipe(id: Int) async throws
    func moveRecipe(id: Int, toCookbookId cookbookId: Int) async throws
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

    /// Fetches full details for a batch of recipes
    func fetchRecipeDetails(cursor: String?, limit: Int) async throws -> RecipeDetailBatchResponse {
        self.logger.info("Fetching recipe details batch")

        var queryItems = [URLQueryItem(name: "limit", value: String(max(limit, 1)))]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        let response: RecipeDetailBatchResponse = try await api.request(
            endpoint: "recipes/batch",
            method: .get,
            queryItems: queryItems,
            authenticated: true
        )

        self.logger.info("Fetched \(response.recipes.count) recipe details from batch")
        return response
    }

    /// Moves a recipe to a different cookbook
    func moveRecipe(id: Int, toCookbookId cookbookId: Int) async throws {
        self.logger.info("Moving recipe \(id) to cookbook \(cookbookId)")

        try await self.api.requestVoid(
            endpoint: "recipes/\(id)",
            method: .patch,
            body: ["cookbook_id": cookbookId],
            authenticated: true
        )

        self.logger.info("Moved recipe \(id) to cookbook \(cookbookId)")
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
