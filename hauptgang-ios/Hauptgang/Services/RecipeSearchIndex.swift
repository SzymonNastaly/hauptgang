import Foundation
import GRDB
import SQLite3
import os

protocol RecipeSearchIndexProtocol: Sendable {
    func configure(userId: Int) async
    func isAvailable() async -> Bool
    func needsRebuild() async -> Bool
    func rebuildIndex(with recipes: [SearchIndexDetailInput]) async
    func indexNames(_ recipes: [SearchIndexNameInput]) async
    func indexDetails(_ details: [SearchIndexDetailInput]) async
    func delete(ids: [Int]) async
    func search(_ query: String, limit: Int) async -> [Int]
    func reset() async
}

actor RecipeSearchIndex: RecipeSearchIndexProtocol {
    static let shared = RecipeSearchIndex()
    private static let schemaVersion = "3"

    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "RecipeSearchIndex")
    private var dbQueue: DatabaseQueue?
    private var available = false
    private var requiresRebuild = false
    private var currentUserId: Int?

    func configure(userId: Int) async {
        guard self.currentUserId != userId else { return }
        self.currentUserId = userId

        guard self.isFTS5Available() else {
            self.logger.info("FTS5 not available; search index disabled")
            self.available = false
            self.dbQueue = nil
            self.requiresRebuild = false
            return
        }

        do {
            let dbPath = try self.databasePath(for: userId)
            self.dbQueue = try DatabaseQueue(path: dbPath)

            let needsRebuild = try await self.dbQueue?.write { db in
                try Self.prepareSchema(in: db)
            }

            self.available = true
            self.requiresRebuild = needsRebuild ?? false
            if needsRebuild == true {
                self.logger.info("Search index schema updated; rebuild required")
            }
        } catch {
            self.logger.error("Failed to initialize search index: \(error.localizedDescription)")
            self.available = false
            self.dbQueue = nil
            self.requiresRebuild = false
        }
    }

    func isAvailable() async -> Bool {
        self.available
    }

    func needsRebuild() async -> Bool {
        self.requiresRebuild
    }

    func rebuildIndex(with recipes: [SearchIndexDetailInput]) async {
        guard self.available, let dbQueue else { return }

        do {
            try await dbQueue.write { db in
                try Self.dropTables(in: db)
                try Self.createTables(in: db)
                try Self.upsertPersisted(recipes, in: db)
            }
            self.requiresRebuild = false
        } catch {
            if await self.recoverFromCorruptionIfNeeded(error: error, userId: self.currentUserId) {
                await self.rebuildIndex(with: recipes)
                return
            }
            self.logger.error("Failed to rebuild search index: \(error.localizedDescription)")
        }
    }

    func indexNames(_ recipes: [SearchIndexNameInput]) async {
        guard self.available, let dbQueue, !recipes.isEmpty else { return }

        do {
            try await dbQueue.write { db in
                try Self.upsertNames(recipes, in: db)
            }
        } catch {
            if await self.recoverFromCorruptionIfNeeded(error: error, userId: self.currentUserId) {
                await self.indexNames(recipes)
                return
            }
            self.logger.error("Failed to index recipe names: \(error.localizedDescription)")
        }
    }

    func indexDetails(_ details: [SearchIndexDetailInput]) async {
        guard self.available, let dbQueue, !details.isEmpty else { return }

        do {
            try await dbQueue.write { db in
                try Self.upsertDetails(details, in: db)
            }
        } catch {
            if await self.recoverFromCorruptionIfNeeded(error: error, userId: self.currentUserId) {
                await self.indexDetails(details)
                return
            }
            self.logger.error("Failed to index recipe details: \(error.localizedDescription)")
        }
    }

    func delete(ids: [Int]) async {
        guard self.available, let dbQueue, !ids.isEmpty else { return }

        do {
            try await dbQueue.write { db in
                let ids = ids
                try db.execute(sql: "DELETE FROM recipes WHERE id IN (\(ids.map { _ in "?" }.joined(separator: ",")))", arguments: StatementArguments(ids))
                try db.execute(sql: "DELETE FROM recipes_fts WHERE rowid IN (\(ids.map { _ in "?" }.joined(separator: ",")))", arguments: StatementArguments(ids))
            }
        } catch {
            if await self.recoverFromCorruptionIfNeeded(error: error, userId: self.currentUserId) {
                await self.delete(ids: ids)
                return
            }
            self.logger.error("Failed to delete recipes from search index: \(error.localizedDescription)")
        }
    }

    func search(_ query: String, limit: Int) async -> [Int] {
        guard self.available, let dbQueue else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ftsQuery = Self.buildFTSQuery(from: trimmed) else { return [] }

        do {
            return try await dbQueue.read { db in
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT recipes.id
                    FROM recipes_fts
                    JOIN recipes ON recipes_fts.rowid = recipes.id
                    WHERE recipes_fts MATCH ?
                    ORDER BY bm25(recipes_fts, 10.0, 3.0, 1.0), recipes.updated_at DESC
                    LIMIT ?
                    """,
                    arguments: [ftsQuery, max(limit, 1)]
                )
                return rows.compactMap { $0["id"] as Int? }
            }
        } catch {
            if await self.recoverFromCorruptionIfNeeded(error: error, userId: self.currentUserId) {
                return await self.search(query, limit: limit)
            }
            self.logger.error("Search query failed: \(error.localizedDescription)")
            return []
        }
    }

    func reset() async {
        await self.resetDatabaseFile()
    }

    // MARK: - Private

    private func isFTS5Available() -> Bool {
        sqlite3_compileoption_used("ENABLE_FTS5") == 1
    }

    private func databasePath(for userId: Int) throws -> String {
        try self.databaseURL(for: userId).path
    }

    private func databaseURL(for userId: Int) throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directory = baseURL.appendingPathComponent("recipe-search", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appendingPathComponent("user-\(userId).sqlite")
    }

    private func resetDatabaseFile() async {
        guard let userId = self.currentUserId else { return }
        do {
            let url = try self.databaseURL(for: userId)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            self.logger.error("Failed to delete search index file: \(error.localizedDescription)")
        }

        self.dbQueue = nil
        self.available = false
        self.requiresRebuild = false
        self.currentUserId = nil
    }

    private static func buildFTSQuery(from raw: String) -> String? {
        RecipeSearchQuery.buildFTSQuery(from: raw)
    }

    private func recoverFromCorruptionIfNeeded(error: Error, userId: Int?) async -> Bool {
        guard let userId else { return false }
        guard let dbError = error as? DatabaseError else { return false }
        let isCorrupt = dbError.resultCode == .SQLITE_CORRUPT || dbError.resultCode == .SQLITE_NOTADB
        guard isCorrupt else { return false }

        self.logger.error("Search index corrupted; rebuilding: \(dbError.message ?? "unknown error")")
        await self.resetDatabaseFile()
        await self.configure(userId: userId)
        return self.available
    }

    private static func prepareSchema(in db: Database) throws -> Bool {
        try db.create(table: "search_metadata", ifNotExists: true) { table in
            table.column("key", .text).primaryKey()
            table.column("value", .text).notNull()
        }

        let existingVersion = try String.fetchOne(
            db,
            sql: "SELECT value FROM search_metadata WHERE key = ?",
            arguments: ["schema_version"]
        )

        if existingVersion != Self.schemaVersion {
            try Self.dropTables(in: db)
            try Self.createTables(in: db)
            try db.execute(
                sql: "INSERT OR REPLACE INTO search_metadata (key, value) VALUES (?, ?)",
                arguments: ["schema_version", Self.schemaVersion]
            )
            return true
        }

        return false
    }

    private static func createTables(in db: Database) throws {
        try db.execute(sql: """
        CREATE TABLE IF NOT EXISTS recipes (
            id INTEGER PRIMARY KEY,
            name TEXT,
            ingredients TEXT,
            instructions TEXT,
            updated_at TEXT
        );
        """)

        try db.execute(sql: """
        CREATE VIRTUAL TABLE IF NOT EXISTS recipes_fts USING fts5(
            name,
            ingredients,
            instructions,
            tokenize='unicode61 remove_diacritics 2',
            prefix='2 3 4'
        );
        """)
    }

    private static func dropTables(in db: Database) throws {
        try db.execute(sql: "DROP TABLE IF EXISTS recipes_fts")
        try db.execute(sql: "DROP TABLE IF EXISTS recipes")
    }

    private static func upsertNames(_ recipes: [SearchIndexNameInput], in db: Database) throws {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for recipe in recipes {
            try db.execute(
                sql: """
                INSERT INTO recipes (id, name, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    updated_at = excluded.updated_at
                """,
                arguments: [recipe.id, recipe.name, dateFormatter.string(from: recipe.updatedAt)]
            )

            try db.execute(
                sql: "DELETE FROM recipes_fts WHERE rowid = ?",
                arguments: [recipe.id]
            )
            try db.execute(
                sql: """
                INSERT INTO recipes_fts (rowid, name, ingredients, instructions)
                VALUES (?, ?, COALESCE((SELECT ingredients FROM recipes WHERE id = ?), ''), COALESCE((SELECT instructions FROM recipes WHERE id = ?), ''))
                """,
                arguments: [recipe.id, recipe.name, recipe.id, recipe.id]
            )
        }
    }

    private static func upsertPersisted(_ recipes: [SearchIndexDetailInput], in db: Database) throws {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for recipe in recipes {
            let ingredients = recipe.ingredients.joined(separator: "\n")
            let instructions = recipe.instructions.joined(separator: "\n")

            try db.execute(
                sql: """
                INSERT INTO recipes (id, name, ingredients, instructions, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    ingredients = excluded.ingredients,
                    instructions = excluded.instructions,
                    updated_at = excluded.updated_at
                """,
                arguments: [
                    recipe.id,
                    recipe.name,
                    ingredients,
                    instructions,
                    dateFormatter.string(from: recipe.updatedAt)
                ]
            )

            try db.execute(
                sql: "DELETE FROM recipes_fts WHERE rowid = ?",
                arguments: [recipe.id]
            )
            try db.execute(
                sql: """
                INSERT INTO recipes_fts (rowid, name, ingredients, instructions)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [recipe.id, recipe.name, ingredients, instructions]
            )
        }
    }

    private static func upsertDetails(_ details: [SearchIndexDetailInput], in db: Database) throws {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for detail in details {
            let ingredients = detail.ingredients.joined(separator: "\n")
            let instructions = detail.instructions.joined(separator: "\n")

            try db.execute(
                sql: """
                INSERT INTO recipes (id, name, ingredients, instructions, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    ingredients = excluded.ingredients,
                    instructions = excluded.instructions,
                    updated_at = excluded.updated_at
                """,
                arguments: [
                    detail.id,
                    detail.name,
                    ingredients,
                    instructions,
                    dateFormatter.string(from: detail.updatedAt)
                ]
            )

            try db.execute(
                sql: "DELETE FROM recipes_fts WHERE rowid = ?",
                arguments: [detail.id]
            )
            try db.execute(
                sql: """
                INSERT INTO recipes_fts (rowid, name, ingredients, instructions)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [detail.id, detail.name, ingredients, instructions]
            )
        }
    }
}
