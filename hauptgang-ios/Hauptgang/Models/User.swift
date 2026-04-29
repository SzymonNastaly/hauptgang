import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: Int
    let email: String
    var name: String?
}
