import Foundation

// MARK: - Recipe List Item

/// Represents a recipe in list views - from GET /api/v1/recipes
struct RecipeListItem: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let prepTime: Int?
    let cookTime: Int?
    let favorite: Bool
    let coverImageUrl: String?
    let updatedAt: Date
}

// MARK: - Recipe Detail

/// Full recipe details - from GET /api/v1/recipes/:id
struct RecipeDetail: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let prepTime: Int?
    let cookTime: Int?
    let favorite: Bool
    let coverImageUrl: String?
    let servings: Int?
    let ingredients: [String]
    let instructions: [String]
    let notes: String?
    let sourceUrl: String?
    let tags: [RecipeTag]
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Recipe Tag

struct RecipeTag: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
}
