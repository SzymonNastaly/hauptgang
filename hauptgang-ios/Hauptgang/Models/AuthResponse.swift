import Foundation

struct AuthResponse: Decodable {
    let token: String
    let expiresAt: Date
    let user: User
}
