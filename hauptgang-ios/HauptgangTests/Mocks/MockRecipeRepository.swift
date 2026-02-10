import Foundation
@testable import Hauptgang
import SwiftData

@MainActor
final class MockRecipeRepository: RecipeRepositoryProtocol {
    var configuredCalled = false
    var savedRecipes: [RecipeListItem] = []
    var savedRecipeDetail: RecipeDetail?
    var cachedRecipe: PersistedRecipe?
    var allRecipes: [PersistedRecipe] = []
    var shouldThrowOnSave = false
    var shouldThrowOnGet = false

    func configure(modelContext _: ModelContext) {
        self.configuredCalled = true
    }

    func saveRecipes(_ recipes: [RecipeListItem]) throws {
        if self.shouldThrowOnSave {
            throw MockRecipeError.networkError
        }
        self.savedRecipes = recipes
    }

    func getAllRecipes() throws -> [PersistedRecipe] {
        if self.shouldThrowOnGet {
            throw MockRecipeError.networkError
        }
        return self.allRecipes
    }

    func clearAllRecipes() throws {
        self.allRecipes = []
        self.cachedRecipe = nil
    }

    func getRecipe(id: Int) throws -> PersistedRecipe? {
        if self.shouldThrowOnGet {
            throw MockRecipeError.networkError
        }
        if self.cachedRecipe?.id == id {
            return self.cachedRecipe
        }
        return nil
    }

    func saveRecipeDetail(_ detail: RecipeDetail) throws {
        if self.shouldThrowOnSave {
            throw MockRecipeError.networkError
        }
        self.savedRecipeDetail = detail
    }

    func deleteRecipe(id: Int) throws {
        self.allRecipes.removeAll { $0.id == id }
    }
}
