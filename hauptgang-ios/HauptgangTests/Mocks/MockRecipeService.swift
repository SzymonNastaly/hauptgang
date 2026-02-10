import Foundation
@testable import Hauptgang

final class MockRecipeService: RecipeServiceProtocol, @unchecked Sendable {
    var fetchRecipesResult: Result<[RecipeListItem], Error> = .success([])
    var fetchRecipesCalled = false
    var fetchRecipesCallCount = 0
    var fetchRecipeDetailResult: Result<RecipeDetail, Error> = .success(
        RecipeDetail.mock()
    )
    var fetchRecipeDetailCalled = false
    var fetchRecipeDetailCalledWithId: Int?

    func fetchRecipes() async throws -> [RecipeListItem] {
        self.fetchRecipesCalled = true
        self.fetchRecipesCallCount += 1
        return try self.fetchRecipesResult.get()
    }

    func fetchRecipeDetail(id: Int) async throws -> RecipeDetail {
        self.fetchRecipeDetailCalled = true
        self.fetchRecipeDetailCalledWithId = id
        return try self.fetchRecipeDetailResult.get()
    }

    var deleteRecipeCalled = false
    var deleteRecipeCalledWithId: Int?
    var deleteRecipeResult: Result<Void, Error> = .success(())

    func deleteRecipe(id: Int) async throws {
        self.deleteRecipeCalled = true
        self.deleteRecipeCalledWithId = id
        try self.deleteRecipeResult.get()
    }
}

enum MockRecipeError: Error, LocalizedError {
    case networkError
    case notFound

    var errorDescription: String? {
        switch self {
        case .networkError:
            "Network connection failed"
        case .notFound:
            "Recipe not found"
        }
    }
}

extension RecipeListItem {
    static func mock(
        id: Int = 1,
        name: String = "Test Recipe",
        prepTime: Int? = 15,
        cookTime: Int? = 30,
        favorite: Bool = false,
        coverImageUrl: String? = nil,
        importStatus: String? = nil,
        errorMessage: String? = nil,
        updatedAt: Date = Date()
    ) -> RecipeListItem {
        RecipeListItem(
            id: id,
            name: name,
            prepTime: prepTime,
            cookTime: cookTime,
            favorite: favorite,
            coverImageUrl: coverImageUrl,
            importStatus: importStatus,
            errorMessage: errorMessage,
            updatedAt: updatedAt
        )
    }
}

extension RecipeDetail {
    static func mock(
        id: Int = 1,
        name: String = "Test Recipe",
        prepTime: Int? = 15,
        cookTime: Int? = 30,
        favorite: Bool = false,
        coverImageUrl: String? = nil,
        servings: Int? = 4,
        ingredients: [String] = ["Ingredient 1", "Ingredient 2"],
        instructions: [String] = ["Step 1", "Step 2"],
        notes: String? = nil,
        sourceUrl: String? = nil,
        tags: [RecipeTag] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> RecipeDetail {
        RecipeDetail(
            id: id,
            name: name,
            prepTime: prepTime,
            cookTime: cookTime,
            favorite: favorite,
            coverImageUrl: coverImageUrl,
            servings: servings,
            ingredients: ingredients,
            instructions: instructions,
            notes: notes,
            sourceUrl: sourceUrl,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
