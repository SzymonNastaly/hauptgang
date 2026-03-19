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

    func saveRecipes(_ recipes: [RecipeListItem], cookbookId _: Int?) throws -> [Int] {
        if self.shouldThrowOnSave {
            throw MockRecipeError.networkError
        }
        self.savedRecipes = recipes
        return []
    }

    func getAllRecipes(cookbookId: Int?) throws -> [PersistedRecipe] {
        if self.shouldThrowOnGet {
            throw MockRecipeError.networkError
        }
        guard let cookbookId else { return self.allRecipes }
        return self.allRecipes.filter { $0.cookbookId == cookbookId }
    }

    func getRecipes(ids: [Int]) throws -> [PersistedRecipe] {
        if self.shouldThrowOnGet {
            throw MockRecipeError.networkError
        }
        return self.allRecipes.filter { ids.contains($0.id) }
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

    func saveRecipeDetail(_ detail: RecipeDetail, cookbookId _: Int?) throws {
        if self.shouldThrowOnSave {
            throw MockRecipeError.networkError
        }
        self.savedRecipeDetail = detail
    }

    func saveRecipeDetails(_ details: [RecipeDetail], cookbookId _: Int?) throws {
        if self.shouldThrowOnSave {
            throw MockRecipeError.networkError
        }
        self.savedRecipeDetail = details.last
    }

    func deleteRecipe(id: Int) throws {
        self.allRecipes.removeAll { $0.id == id }
    }
}
