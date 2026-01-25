import Foundation
import SwiftUI

/// App-wide authentication state manager
/// Injected as an environment object for global access
@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var authState: AuthState = .unknown

    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol = AuthService.shared) {
        self.authService = authService
    }

    // MARK: - Auth State

    enum AuthState: Equatable {
        case unknown
        case unauthenticated
        case authenticated(User)

        var isAuthenticated: Bool {
            if case .authenticated = self { return true }
            return false
        }

        var user: User? {
            if case .authenticated(let user) = self { return user }
            return nil
        }

        static func == (lhs: AuthState, rhs: AuthState) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown):
                return true
            case (.unauthenticated, .unauthenticated):
                return true
            case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
                return lhsUser == rhsUser
            default:
                return false
            }
        }
    }

    // MARK: - Public Methods

    /// Check authentication status on app launch
    func checkAuthStatus() async {
        if let user = await authService.getCurrentUser() {
            authState = .authenticated(user)
        } else {
            authState = .unauthenticated
        }
    }

    /// Update state after successful login
    func signIn(user: User) {
        authState = .authenticated(user)
    }

    /// Sign out and clear credentials
    func signOut() async {
        await authService.logout()
        authState = .unauthenticated
    }
}
