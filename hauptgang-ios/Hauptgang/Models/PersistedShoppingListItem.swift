import Foundation
import SwiftData

enum ShoppingListSyncState: String, Codable {
    case pendingCreate = "pending_create"
    case pendingUpdate = "pending_update"
    case synced = "synced"
}

@Model
final class PersistedShoppingListItem {
    @Attribute(.unique) var clientId: String
    var serverId: Int?
    var name: String
    var checkedAt: Date?
    var sourceRecipeId: Int?
    var createdAt: Date
    var updatedAt: Date
    var syncStateRaw: String

    var syncState: ShoppingListSyncState {
        get { ShoppingListSyncState(rawValue: syncStateRaw) ?? .synced }
        set { syncStateRaw = newValue.rawValue }
    }

    var isChecked: Bool { checkedAt != nil }

    var isStale: Bool {
        guard let checkedAt else { return false }
        return checkedAt < Date().addingTimeInterval(-3600)
    }

    init(
        clientId: String,
        name: String,
        checkedAt: Date? = nil,
        sourceRecipeId: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        serverId: Int? = nil,
        syncState: ShoppingListSyncState = .pendingCreate
    ) {
        self.clientId = clientId
        self.name = name
        self.checkedAt = checkedAt
        self.sourceRecipeId = sourceRecipeId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverId = serverId
        self.syncStateRaw = syncState.rawValue
    }

    convenience init(from response: ShoppingListItemResponse) {
        self.init(
            clientId: response.clientId,
            name: response.name,
            checkedAt: response.checkedAt,
            sourceRecipeId: response.sourceRecipeId,
            createdAt: response.createdAt,
            updatedAt: response.updatedAt,
            serverId: response.id,
            syncState: .synced
        )
    }

    func update(from response: ShoppingListItemResponse) {
        serverId = response.id
        name = response.name
        checkedAt = response.checkedAt
        sourceRecipeId = response.sourceRecipeId
        createdAt = response.createdAt
        updatedAt = response.updatedAt
        syncState = .synced
    }
}
