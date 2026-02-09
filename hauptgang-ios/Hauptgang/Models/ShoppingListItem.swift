import Foundation

struct ShoppingListItemResponse: Codable, Identifiable, Sendable {
    let id: Int
    let clientId: String
    let name: String
    let checkedAt: Date?
    let sourceRecipeId: Int?
    let createdAt: Date
    let updatedAt: Date
}

struct ShoppingListItemCreate: Codable, Sendable {
    let clientId: String
    let name: String
    let checkedAt: Date?
    let sourceRecipeId: Int?
}

struct BulkCreateShoppingListItemsRequest: Codable, Sendable {
    let items: [ShoppingListItemCreate]
}

struct UpdateShoppingListItemRequest: Codable, Sendable {
    let checked: Bool
    let checkedAt: Date?
}
