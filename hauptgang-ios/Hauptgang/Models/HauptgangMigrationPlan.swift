import Foundation
import SwiftData

enum HauptgangMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [HauptgangSchemaV1.self, HauptgangSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// V1 → V2: Wipe local cache — data re-syncs from the server.
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: HauptgangSchemaV1.self,
        toVersion: HauptgangSchemaV2.self,
        willMigrate: { context in
            try context.delete(model: HauptgangSchemaV1.PersistedRecipe.self)
            try context.delete(model: HauptgangSchemaV1.PersistedShoppingListItem.self)
            try context.save()
        },
        didMigrate: nil
    )
}
