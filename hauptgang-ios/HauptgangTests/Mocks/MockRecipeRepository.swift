import Foundation
import SwiftData
@testable import Hauptgang

@MainActor
final class MockRecipeRepository: RecipeRepositoryProtocol {
    var configuredCalled = false
    var savedRecipes: [RecipeListItem] = []
    var savedRecipeDetail: RecipeDetail?
    var cachedRecipe: PersistedRecipe?
    var allRecipes: [PersistedRecipe] = []
    var shouldThrowOnSave = false
    var shouldThrowOnGet = false

    func configure(modelContext: ModelContext) {
        configuredCalled = true
    }

    func saveRecipes(_ recipes: [RecipeListItem]) throws {
        if shouldThrowOnSave {
            throw MockRecipeError.networkError
        }
        savedRecipes = recipes
    }

    func getAllRecipes() throws -> [PersistedRecipe] {
        if shouldThrowOnGet {
            throw MockRecipeError.networkError
        }
        return allRecipes
    }

    func clearAllRecipes() throws {
        allRecipes = []
        cachedRecipe = nil
    }

    func getRecipe(id: Int) throws -> PersistedRecipe? {
        if shouldThrowOnGet {
            throw MockRecipeError.networkError
        }
        if cachedRecipe?.id == id {
            return cachedRecipe
        }
        return nil
    }

    func saveRecipeDetail(_ detail: RecipeDetail) throws {
        if shouldThrowOnSave {
            throw MockRecipeError.networkError
        }
        savedRecipeDetail = detail
    }
}
