import Foundation
import SwiftUI

/// Login/signup form state and validation
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var passwordConfirmation = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSignUp = false {
        didSet {
            errorMessage = nil
            passwordConfirmation = ""
        }
    }

    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol = AuthService.shared) {
        self.authService = authService
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let trimmedEmail = self.email.trimmingCharacters(in: .whitespaces)
        let baseValid = !trimmedEmail.isEmpty &&
            !self.password.isEmpty &&
            self.isValidEmail(trimmedEmail)

        if self.isSignUp {
            return baseValid &&
                self.password.count >= 12 &&
                self.password == self.passwordConfirmation
        }

        return baseValid
    }

    var emailError: String? {
        let trimmed = self.email.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        if !self.isValidEmail(trimmed) { return "Please enter a valid email" }
        return nil
    }

    var passwordConfirmationError: String? {
        guard self.isSignUp, !self.passwordConfirmation.isEmpty else { return nil }
        if self.password != self.passwordConfirmation {
            return "Passwords don't match"
        }
        return nil
    }

    // MARK: - Login

    func login(authManager: AuthManager) async {
        guard self.isFormValid else { return }

        self.isLoading = true
        self.errorMessage = nil

        do {
            let user = try await authService.login(
                email: self.email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: self.password
            )

            self.password = ""

            authManager.signIn(user: user)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            self.errorMessage = "An unexpected error occurred. Please try again."
        }

        self.isLoading = false
    }

    // MARK: - Signup

    func signup(authManager: AuthManager) async {
        guard self.isFormValid else { return }

        self.isLoading = true
        self.errorMessage = nil

        do {
            let user = try await authService.signup(
                email: self.email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: self.password,
                passwordConfirmation: self.passwordConfirmation
            )

            self.password = ""
            self.passwordConfirmation = ""

            authManager.signIn(user: user)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            self.errorMessage = "An unexpected error occurred. Please try again."
        }

        self.isLoading = false
    }

    // MARK: - Private

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}
