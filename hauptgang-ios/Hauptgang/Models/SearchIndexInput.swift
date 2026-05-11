import Foundation

struct SearchIndexNameInput {
    let id: Int
    let name: String
    let updatedAt: Date
}

struct SearchIndexDetailInput {
    let id: Int
    let name: String
    let ingredients: [String]
    let instructions: [String]
    let updatedAt: Date
}
