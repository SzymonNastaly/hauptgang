import Foundation

struct SearchIndexNameInput: Sendable {
    let id: Int
    let name: String
    let updatedAt: Date
}

struct SearchIndexDetailInput: Sendable {
    let id: Int
    let name: String
    let ingredients: [String]
    let instructions: [String]
    let updatedAt: Date
}
