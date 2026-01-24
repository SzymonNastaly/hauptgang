import Foundation
import SwiftUI

/// Login form state and validation
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol = AuthService.shared) {
        self.authService = authService
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        return !trimmedEmail.isEmpty &&
            !password.isEmpty &&
            isValidEmail(trimmedEmail)
    }

    var emailError: String? {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        if !isValidEmail(trimmed) { return "Please enter a valid email" }
        return nil
    }

    // MARK: - Login

    func login(authManager: AuthManager) async {
        guard isFormValid else { return }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.login(
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: password
            )

            // Clear sensitive data from memory
            password = ""

            authManager.signIn(user: user)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
        }

        isLoading = false
    }

    // MARK: - Private

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}
