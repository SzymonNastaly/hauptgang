import Foundation
import SwiftData

/// Original schema — matches what's on TestFlight users' devices (no cookbookId)
enum HauptgangSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [PersistedRecipe.self, PersistedShoppingListItem.self]
    }

    // Names MUST match the top-level model class names so SwiftData
    // recognises them as the same tables.

    @Model
    final class PersistedRecipe {
        @Attribute(.unique) var id: Int
        var name: String
        var prepTime: Int?
        var cookTime: Int?
        var favorite: Bool
        var coverImageUrl: String?
        var importStatus: String?
        var errorMessage: String?
        var updatedAt: Date
        var lastFetchedAt: Date
        var servings: Int?
        var notes: String?
        var sourceUrl: String?
        var createdAt: Date?
        var detailLastFetchedAt: Date?
        var ingredientsJson: String?
        var instructionsJson: String?
        var tagsJson: String?

        init() {
            self.id = 0
            self.name = ""
            self.favorite = false
            self.updatedAt = Date()
            self.lastFetchedAt = Date()
        }
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

        init() {
            self.clientId = ""
            self.name = ""
            self.createdAt = Date()
            self.updatedAt = Date()
            self.syncStateRaw = "synced"
        }
    }
}
