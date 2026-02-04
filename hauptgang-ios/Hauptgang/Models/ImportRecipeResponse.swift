import Foundation

/// Response from POST /api/v1/recipes/import
struct ImportRecipeResponse: Codable, Sendable {
    let id: Int
    let importStatus: String
}
