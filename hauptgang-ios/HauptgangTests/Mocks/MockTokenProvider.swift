import Foundation
@testable import Hauptgang

actor MockTokenProvider: TokenProviding {
    var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func getToken() async -> String? {
        token
    }

    func setToken(_ newToken: String?) {
        token = newToken
    }
}
