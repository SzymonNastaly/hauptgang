import Foundation

struct User: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let email: String
}
