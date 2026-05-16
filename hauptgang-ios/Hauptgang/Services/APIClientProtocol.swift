import Foundation

/// Protocol for providing authentication tokens
protocol TokenProviding: Sendable {
    func getToken() async -> String?
}

/// Bundles the file payload for a multipart upload to keep call sites under the
/// function-parameter limit.
struct MultipartFile {
    let data: Data
    let fileName: String
    let mimeType: String
    let paramName: String
}

/// Protocol defining the API client interface for testability
protocol APIClientProtocol: Actor {
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        queryItems: [URLQueryItem]?,
        authenticated: Bool
    ) async throws -> T

    func requestVoid(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable?,
        queryItems: [URLQueryItem]?,
        authenticated: Bool
    ) async throws

    func uploadMultipart<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        file: MultipartFile,
        authenticated: Bool
    ) async throws -> T
}

extension APIClientProtocol {
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable? = nil,
        authenticated: Bool = false
    ) async throws -> T {
        try await self.request(
            endpoint: endpoint,
            method: method,
            body: body,
            queryItems: nil,
            authenticated: authenticated
        )
    }

    func requestVoid(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable? = nil,
        authenticated: Bool = false
    ) async throws {
        try await self.requestVoid(
            endpoint: endpoint,
            method: method,
            body: body,
            queryItems: nil,
            authenticated: authenticated
        )
    }

    func uploadMultipart<T: Decodable>(
        endpoint: String,
        file: MultipartFile,
        authenticated: Bool = false
    ) async throws -> T {
        try await self.uploadMultipart(
            endpoint: endpoint,
            method: .post,
            file: file,
            authenticated: authenticated
        )
    }
}
