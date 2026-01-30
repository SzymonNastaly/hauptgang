import Foundation

/// Service for importing recipes from URLs
actor RecipeImportService {
    static let shared = RecipeImportService()

    private init() {}

    /// Import a recipe from a URL (fire-and-forget)
    /// The server creates a pending recipe and processes it asynchronously
    func importRecipe(from url: URL) async throws -> ImportRecipeResponse {
        struct ImportRequest: Encodable {
            let url: String
        }

        return try await APIClient.shared.request(
            endpoint: "recipes/import",
            method: .post,
            body: ImportRequest(url: url.absoluteString),
            authenticated: true
        )
    }
}
