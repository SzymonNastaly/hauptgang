import Foundation
@testable import Hauptgang

/// Mock authentication service for testing
/// Allows controlling login results and tracking method calls
final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    var loginResult: Result<User, Error> = .success(User(id: 1, email: "test@example.com"))
    var logoutCalled = false
    var currentUser: User?

    func login(email _: String, password _: String) async throws -> User {
        try self.loginResult.get()
    }

    func logout() async {
        self.logoutCalled = true
        self.currentUser = nil
    }

    func getCurrentUser() async -> User? {
        self.currentUser
    }

    func isAuthenticated() async -> Bool {
        self.currentUser != nil
    }
}

/// Error type for testing failure scenarios
enum MockAuthError: Error, LocalizedError {
    case invalidCredentials
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid email or password"
        case .networkError:
            "Network connection failed"
        }
    }
}
