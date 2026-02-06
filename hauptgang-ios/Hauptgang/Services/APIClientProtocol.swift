import Foundation

/// Protocol for providing authentication tokens
protocol TokenProviding: Sendable {
    func getToken() async -> String?
}

/// Protocol defining the API client interface for testability
protocol APIClientProtocol: Actor {
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        authenticated: Bool
    ) async throws -> T

    func requestVoid(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        authenticated: Bool
    ) async throws

    func uploadMultipart<T: Decodable>(
        endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        paramName: String,
        authenticated: Bool
    ) async throws -> T
}
