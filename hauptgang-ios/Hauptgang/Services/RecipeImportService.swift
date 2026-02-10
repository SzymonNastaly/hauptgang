import Foundation

/// Service for importing recipes from URLs
actor RecipeImportService {
    static let shared = RecipeImportService()

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    /// Import a recipe from a URL (fire-and-forget)
    /// The server creates a pending recipe and processes it asynchronously
    func importRecipe(from url: URL) async throws -> ImportRecipeResponse {
        struct ImportRequest: Encodable {
            let url: String
        }

        return try await self.apiClient.request(
            endpoint: "recipes/import",
            method: .post,
            body: ImportRequest(url: url.absoluteString),
            authenticated: true
        )
    }

    /// Import a recipe from image data
    func importRecipe(from imageData: Data, mimeType: String = "image/jpeg") async throws -> ImportRecipeResponse {
        try await self.apiClient.uploadMultipart(
            endpoint: "recipes/extract_from_image",
            fileData: imageData,
            fileName: "recipe.\(mimeType == "image/png" ? "png" : "jpg")",
            mimeType: mimeType,
            paramName: "image",
            authenticated: true
        )
    }
}
