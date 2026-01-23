import Foundation
import UIKit

/// Coordinates authentication operations between API and Keychain
final class AuthService {
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
        try keychain.saveToken(response.token, expiresAt: response.expiresAt)
        try keychain.saveUser(response.user)

        return response.user
    }

    // MARK: - Logout

    func logout() async {
        // Best effort server-side logout
        do {
            try await api.requestVoid(
                endpoint: "session",
                method: .delete,
                authenticated: true
            )
        } catch {
            // Continue with local cleanup even if server logout fails
            print("Server logout failed: \(error.localizedDescription)")
        }

        // Always clear local credentials
        keychain.clearAll()
    }

    // MARK: - Session Check

    func getCurrentUser() -> User? {
        // Token validity is checked in getToken()
        guard keychain.getToken() != nil else {
            // Token missing or expired, clear user data
            keychain.clearAll()
            return nil
        }

        return keychain.getUser()
    }

    func isAuthenticated() -> Bool {
        return getCurrentUser() != nil
    }

    // MARK: - Private

    @MainActor
    private func getDeviceName() -> String {
        return UIDevice.current.name
    }
}

// MARK: - Request Types

private struct LoginRequest: Encodable {
    let email: String
    let password: String
    let deviceName: String
}
