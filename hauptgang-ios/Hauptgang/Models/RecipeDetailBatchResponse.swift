import Foundation

/// Bulk recipe detail response - from GET /api/v1/recipes/batch
struct RecipeDetailBatchResponse: Codable {
    let recipes: [RecipeDetail]
    let nextCursor: String?
}
