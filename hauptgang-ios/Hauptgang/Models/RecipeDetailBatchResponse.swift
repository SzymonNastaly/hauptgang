import Foundation

/// Bulk recipe detail response - from GET /api/v1/recipes/batch
struct RecipeDetailBatchResponse: Codable, Sendable {
    let recipes: [RecipeDetail]
    let nextCursor: String?
}
