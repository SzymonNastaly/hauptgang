import Foundation

enum Constants {
    enum API {
        #if DEBUG
        // Local development - use your Mac's IP for device testing
        // For simulator: localhost works fine
        static let baseURL = URL(string: "http://127.0.0.1:3000/api/v1")!
        #else
        // Production URL - update when deploying
        static let baseURL = URL(string: "https://hauptgang.example.com/api/v1")!
        #endif

        static let sessionPath = "/session"
    }

    enum Keychain {
        static let service = "com.hauptgang.ios"
        static let tokenKey = "auth_token"
        static let tokenExpiryKey = "auth_token_expiry"
        static let userKey = "current_user"
    }
}
