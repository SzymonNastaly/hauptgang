import Foundation
import SwiftData

/// SwiftData model for offline recipe storage
@Model
final class PersistedRecipe {
    /// Unique identifier from the API - ensures no duplicates
    @Attribute(.unique) var id: Int

    var name: String
    var prepTime: Int?
    var cookTime: Int?
    var favorite: Bool
    var coverImageUrl: String?
    var importStatus: String?
    var errorMessage: String?
    var updatedAt: Date

    /// Tracks when this record was last synced from the API
    var lastFetchedAt: Date

    // MARK: - Detail Fields (nil until detail is fetched)

    var servings: Int?
    var notes: String?
    var sourceUrl: String?
    var createdAt: Date?

    /// Tracks when details were cached (nil if only list data is cached)
    var detailLastFetchedAt: Date?

    // MARK: - Arrays stored as JSON strings

    var ingredientsJson: String?
    var instructionsJson: String?
    var tagsJson: String?

    // MARK: - Computed Properties for JSON Arrays

    var ingredients: [String] {
        get {
            guard let json = ingredientsJson,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            self.ingredientsJson = try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)
        }
    }

    var instructions: [String] {
        get {
            guard let json = instructionsJson,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            self.instructionsJson = try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)
        }
    }

    var tags: [RecipeTag] {
        get {
            guard let json = tagsJson,
                  let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([RecipeTag].self, from: data)) ?? []
        }
        set {
            self.tagsJson = try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)
        }
    }

    /// Whether full recipe details have been cached
    var hasDetailsCached: Bool {
        self.detailLastFetchedAt != nil
    }

    // MARK: - Initializers

    init(
        id: Int,
        name: String,
        prepTime: Int? = nil,
        cookTime: Int? = nil,
        favorite: Bool = false,
        coverImageUrl: String? = nil,
        importStatus: String? = nil,
        errorMessage: String? = nil,
        updatedAt: Date,
        lastFetchedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.favorite = favorite
        self.coverImageUrl = coverImageUrl
        self.importStatus = importStatus
        self.errorMessage = errorMessage
        self.updatedAt = updatedAt
        self.lastFetchedAt = lastFetchedAt
    }

    /// Convenience initializer from API list response
    convenience init(from listItem: RecipeListItem) {
        self.init(
            id: listItem.id,
            name: listItem.name,
            prepTime: listItem.prepTime,
            cookTime: listItem.cookTime,
            favorite: listItem.favorite,
            coverImageUrl: listItem.coverImageUrl,
            importStatus: listItem.importStatus,
            errorMessage: listItem.errorMessage,
            updatedAt: listItem.updatedAt
        )
    }

    /// Convenience initializer from API detail response
    convenience init(from detail: RecipeDetail) {
        self.init(
            id: detail.id,
            name: detail.name,
            prepTime: detail.prepTime,
            cookTime: detail.cookTime,
            favorite: detail.favorite,
            coverImageUrl: detail.coverImageUrl,
            updatedAt: detail.updatedAt
        )
        self.updateDetails(from: detail)
    }

    // MARK: - Update Methods

    /// Update this model from a newer API list response
    func update(from listItem: RecipeListItem) {
        self.name = listItem.name
        self.prepTime = listItem.prepTime
        self.cookTime = listItem.cookTime
        self.favorite = listItem.favorite
        self.coverImageUrl = listItem.coverImageUrl
        self.importStatus = listItem.importStatus
        self.errorMessage = listItem.errorMessage
        self.updatedAt = listItem.updatedAt
        self.lastFetchedAt = Date()
    }

    /// Update this model with full detail data from API
    func update(from detail: RecipeDetail) {
        self.name = detail.name
        self.prepTime = detail.prepTime
        self.cookTime = detail.cookTime
        self.favorite = detail.favorite
        self.coverImageUrl = detail.coverImageUrl
        self.updatedAt = detail.updatedAt
        self.lastFetchedAt = Date()
        self.updateDetails(from: detail)
    }

    /// Helper to update detail-specific fields
    private func updateDetails(from detail: RecipeDetail) {
        self.servings = detail.servings
        self.notes = detail.notes
        self.sourceUrl = detail.sourceUrl
        self.createdAt = detail.createdAt
        self.ingredients = detail.ingredients
        self.instructions = detail.instructions
        self.tags = detail.tags
        self.detailLastFetchedAt = Date()
    }

    // MARK: - Conversion

    /// Convert to RecipeDetail for use in views (returns nil if details not cached)
    func toRecipeDetail() -> RecipeDetail? {
        guard self.hasDetailsCached else { return nil }

        return RecipeDetail(
            id: self.id,
            name: self.name,
            prepTime: self.prepTime,
            cookTime: self.cookTime,
            favorite: self.favorite,
            coverImageUrl: self.coverImageUrl,
            servings: self.servings,
            ingredients: self.ingredients,
            instructions: self.instructions,
            notes: self.notes,
            sourceUrl: self.sourceUrl,
            tags: self.tags,
            createdAt: self.createdAt ?? self.updatedAt,
            updatedAt: self.updatedAt
        )
    }
}
