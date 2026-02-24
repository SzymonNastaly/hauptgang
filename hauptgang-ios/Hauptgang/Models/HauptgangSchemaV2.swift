import Foundation
import SwiftData

/// Schema V2 — adds cookbookId to recipes and shopping list items
enum HauptgangSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Hauptgang.PersistedRecipe.self, Hauptgang.PersistedShoppingListItem.self]
    }
}
