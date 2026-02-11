import Foundation
import UIKit

/// Coordinates authentication operations between API and Keychain
final class AuthService: AuthServiceProtocol {
    static let shared = AuthService()

    private let keychain = KeychainService.shared
    private let api = APIClient.shared

    private init() {}

    // MARK: - Login

    func login(email: String, password: String) async throws -> User {
        let deviceName = await getDeviceName()

        let request = LoginRequest(
            email: email,
            password: password,
            deviceName: deviceName
        )

        let response: AuthResponse = try await api.request(
            endpoint: "session",
            method: .post,
            body: request
        )

        // Store credentials securely
        try await self.keychain.saveToken(response.token, expiresAt: response.expiresAt)
        try await self.keychain.saveUser(response.user)

        return response.user
    }

    // MARK: - Signup

    func signup(email: String, password: String, passwordConfirmation: String) async throws -> User {
        let deviceName = await getDeviceName()

        let request = SignupRequest(
            email: email,
            password: password,
            passwordConfirmation: passwordConfirmation,
            deviceName: deviceName
        )

        let response: AuthResponse = try await api.request(
            endpoint: "registration",
            method: .post,
            body: request
        )

        try await self.keychain.saveToken(response.token, expiresAt: response.expiresAt)
        try await self.keychain.saveUser(response.user)

        return response.user
    }

    // MARK: - Logout

    func logout() async {
        // Best effort server-side logout
        do {
            try await self.api.requestVoid(
                endpoint: "session",
                method: .delete,
                authenticated: true
            )
        } catch {
            // Continue with local cleanup even if server logout fails
            print("Server logout failed: \(error.localizedDescription)")
        }

        // Always clear local credentials
        await self.keychain.clearAll()
    }

    // MARK: - Session Check

    func getCurrentUser() async -> User? {
        // Token validity is checked in getToken()
        guard await self.keychain.getToken() != nil else {
            // Token missing or expired, clear user data
            await self.keychain.clearAll()
            return nil
        }

        return await self.keychain.getUser()
    }

    func isAuthenticated() async -> Bool {
        await self.getCurrentUser() != nil
    }

    // MARK: - Private

    @MainActor
    private func getDeviceName() -> String {
        UIDevice.current.name
    }
}

// MARK: - Request Types

private struct LoginRequest: Encodable {
    let email: String
    let password: String
    let deviceName: String
}

private struct SignupRequest: Encodable {
    let email: String
    let password: String
    let passwordConfirmation: String
    let deviceName: String
}
