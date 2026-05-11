import Foundation
import SwiftData

/// Schema V6 — adds optional `details` to `PersistedShoppingListItem` so each
/// shopping list row carries a secondary line (e.g. quantity / preparation).
/// References the live model classes; the migration from V5 is lightweight.
enum HauptgangSchemaV6: VersionedSchema {
    static let versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Hauptgang.PersistedRecipe.self,
            Hauptgang.PersistedShoppingListItem.self,
            Hauptgang.PersistedMealPlanDay.self,
            Hauptgang.PersistedMealPlanEntry.self
        ]
    }
}
