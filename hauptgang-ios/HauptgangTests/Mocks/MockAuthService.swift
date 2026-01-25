import Foundation
@testable import Hauptgang

/// Mock authentication service for testing
/// Allows controlling login results and tracking method calls
final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    var loginResult: Result<User, Error> = .success(User(id: 1, email: "test@example.com"))
    var logoutCalled = false
    var currentUser: User?

    func login(email: String, password: String) async throws -> User {
        try loginResult.get()
    }

    func logout() async {
        logoutCalled = true
        currentUser = nil
    }

    func getCurrentUser() async -> User? {
        currentUser
    }

    func isAuthenticated() async -> Bool {
        currentUser != nil
    }
}

/// Error type for testing failure scenarios
enum MockAuthError: Error, LocalizedError {
    case invalidCredentials
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection failed"
        }
    }
}
