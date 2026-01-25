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
    var updatedAt: Date

    /// Tracks when this record was last synced from the API
    var lastFetchedAt: Date

    init(
        id: Int,
        name: String,
        prepTime: Int? = nil,
        cookTime: Int? = nil,
        favorite: Bool = false,
        coverImageUrl: String? = nil,
        updatedAt: Date,
        lastFetchedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.favorite = favorite
        self.coverImageUrl = coverImageUrl
        self.updatedAt = updatedAt
        self.lastFetchedAt = lastFetchedAt
    }

    /// Convenience initializer from API response
    convenience init(from listItem: RecipeListItem) {
        self.init(
            id: listItem.id,
            name: listItem.name,
            prepTime: listItem.prepTime,
            cookTime: listItem.cookTime,
            favorite: listItem.favorite,
            coverImageUrl: listItem.coverImageUrl,
            updatedAt: listItem.updatedAt
        )
    }

    /// Update this model from a newer API response
    func update(from listItem: RecipeListItem) {
        name = listItem.name
        prepTime = listItem.prepTime
        cookTime = listItem.cookTime
        favorite = listItem.favorite
        coverImageUrl = listItem.coverImageUrl
        updatedAt = listItem.updatedAt
        lastFetchedAt = Date()
    }
}
