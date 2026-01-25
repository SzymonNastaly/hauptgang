import Foundation
import Security

/// Secure storage for authentication tokens using iOS Keychain
actor KeychainService {
    static let shared = KeychainService()

    private let service = Constants.Keychain.service

    // MARK: - Token Storage

    func saveToken(_ token: String, expiresAt: Date) throws {
        try save(key: Constants.Keychain.tokenKey, data: Data(token.utf8))

        let expiryData = try JSONEncoder().encode(expiresAt)
        try save(key: Constants.Keychain.tokenExpiryKey, data: expiryData)
    }

    func getToken() -> String? {
        guard let data = get(key: Constants.Keychain.tokenKey) else { return nil }

        // Check if token is expired
        if let expiryData = get(key: Constants.Keychain.tokenExpiryKey),
           let expiresAt = try? JSONDecoder().decode(Date.self, from: expiryData) {
            if Date() >= expiresAt {
                // Token expired, clean up
                deleteToken()
                return nil
            }
        }

        return String(data: data, encoding: .utf8)
    }

    func deleteToken() {
        delete(key: Constants.Keychain.tokenKey)
        delete(key: Constants.Keychain.tokenExpiryKey)
    }

    // MARK: - User Storage

    func saveUser(_ user: User) throws {
        let data = try JSONEncoder().encode(user)
        try save(key: Constants.Keychain.userKey, data: data)
    }

    func getUser() -> User? {
        guard let data = get(key: Constants.Keychain.userKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    func deleteUser() {
        delete(key: Constants.Keychain.userKey)
    }

    // MARK: - Clear All

    func clearAll() {
        deleteToken()
        deleteUser()
    }

    // MARK: - Private Keychain Operations

    private func save(key: String, data: Data) throws {
        // Delete any existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // Only accessible after device first unlock, not synced to other devices
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unableToSave(status)
        }
    }

    private func get(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }

        return result as? Data
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case unableToSave(OSStatus)
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .unableToSave(let status):
            return "Unable to save to Keychain (status: \(status))"
        case .itemNotFound:
            return "Item not found in Keychain"
        }
    }
}
