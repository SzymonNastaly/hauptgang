import Foundation
import os

/// Protocol for recipe API operations - enables mocking in tests
protocol RecipeServiceProtocol: Sendable {
    func fetchRecipes() async throws -> [RecipeListItem]
}

/// Handles all recipe-related API calls
final class RecipeService: RecipeServiceProtocol {
    static let shared = RecipeService()

    private let api = APIClient.shared
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeService")

    private init() {}

    /// Fetches all recipes for the authenticated user
    func fetchRecipes() async throws -> [RecipeListItem] {
        logger.info("Fetching recipes from API")

        let recipes: [RecipeListItem] = try await api.request(
            endpoint: "recipes",
            method: .get,
            authenticated: true
        )

        logger.info("Fetched \(recipes.count) recipes from API")
        return recipes
    }
}
