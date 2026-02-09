import Foundation
import os

protocol ShoppingListServiceProtocol: Sendable {
    func fetchItems() async throws -> [ShoppingListItemResponse]
    func createItems(_ items: [ShoppingListItemCreate]) async throws -> [ShoppingListItemResponse]
    func updateItem(id: Int, checked: Bool, checkedAt: Date?) async throws -> ShoppingListItemResponse
    func deleteItem(id: Int) async throws
}

final class ShoppingListService: ShoppingListServiceProtocol, @unchecked Sendable {
    static let shared = ShoppingListService()

    private let api = APIClient.shared
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "ShoppingListService")

    private init() {}

    func fetchItems() async throws -> [ShoppingListItemResponse] {
        logger.info("Fetching shopping list items from API")

        let items: [ShoppingListItemResponse] = try await api.request(
            endpoint: "shopping_list_items",
            method: .get,
            authenticated: true
        )

        logger.info("Fetched \(items.count) shopping list items from API")
        return items
    }

    func createItems(_ items: [ShoppingListItemCreate]) async throws -> [ShoppingListItemResponse] {
        logger.info("Creating \(items.count) shopping list items")

        let request = BulkCreateShoppingListItemsRequest(items: items)
        let created: [ShoppingListItemResponse] = try await api.request(
            endpoint: "shopping_list_items",
            method: .post,
            body: request,
            authenticated: true
        )

        logger.info("Created \(created.count) shopping list items")
        return created
    }

    func updateItem(id: Int, checked: Bool, checkedAt: Date?) async throws -> ShoppingListItemResponse {
        let request = UpdateShoppingListItemRequest(checked: checked, checkedAt: checkedAt)
        let item: ShoppingListItemResponse = try await api.request(
            endpoint: "shopping_list_items/\(id)",
            method: .patch,
            body: request,
            authenticated: true
        )

        logger.info("Updated shopping list item \(id)")
        return item
    }

    func deleteItem(id: Int) async throws {
        logger.info("Deleting shopping list item \(id)")

        try await api.requestVoid(
            endpoint: "shopping_list_items/\(id)",
            method: .delete,
            authenticated: true
        )
    }
}
