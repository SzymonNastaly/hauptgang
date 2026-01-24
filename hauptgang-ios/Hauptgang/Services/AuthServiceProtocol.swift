import Foundation

/// Protocol defining authentication service operations
/// Enables dependency injection for testing
protocol AuthServiceProtocol: Sendable {
    func login(email: String, password: String) async throws -> User
    func logout() async
    func getCurrentUser() -> User?
    func isAuthenticated() -> Bool
}
