import Foundation

enum Constants {
    enum API {
        #if DEBUG
        // Local development - use your Mac's IP for device testing
        // For simulator: localhost works fine
        static let host = URL(string: "http://127.0.0.1:3000")!
        static let baseURL = URL(string: "http://127.0.0.1:3000/api/v1")!
        #else
        // Production URL - update when deploying
        static let host = URL(string: "https://hauptgang.example.com")!
        static let baseURL = URL(string: "https://hauptgang.example.com/api/v1")!
        #endif

        static let sessionPath = "/session"

        /// Resolves a relative path (e.g., "/rails/active_storage/...") to a full URL
        static func resolveURL(_ path: String?) -> URL? {
            guard let path, !path.isEmpty else { return nil }
            if path.hasPrefix("http://") || path.hasPrefix("https://") {
                return URL(string: path)
            }
            return URL(string: path, relativeTo: host)
        }
    }

    enum Keychain {
        static let service = "com.hauptgang.ios"
        static let tokenKey = "auth_token"
        static let tokenExpiryKey = "auth_token_expiry"
        static let userKey = "current_user"
        /// Shared access group for Keychain sharing between app and extensions.
        /// Read from Info.plist where $(AppIdentifierPrefix) is expanded at build time.
        /// Returns nil if not configured, which uses the app's default access group.
        static var accessGroup: String? {
            Bundle.main.object(forInfoDictionaryKey: "KeychainAccessGroup") as? String
        }
    }
}
