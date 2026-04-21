import Foundation

// MARK: - Recipe List Item

/// Represents a recipe in list views - from GET /api/v1/recipes
struct RecipeListItem: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let prepTime: Int?
    let cookTime: Int?
    let favorite: Bool
    // TODO: Remove legacy coverImageUrl fallback once the backend no longer serves
    // the old cover_image_url field for older app builds.
    let coverImageUrl: String?
    let coverImages: RecipeCoverImages?
    let importStatus: String?
    let errorMessage: String?
    let updatedAt: Date

    init(
        id: Int,
        name: String,
        prepTime: Int? = nil,
        cookTime: Int? = nil,
        favorite: Bool,
        coverImageUrl: String? = nil,
        coverImages: RecipeCoverImages? = nil,
        importStatus: String? = nil,
        errorMessage: String? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.favorite = favorite
        self.coverImageUrl = coverImageUrl
        self.coverImages = coverImages
        self.importStatus = importStatus
        self.errorMessage = errorMessage
        self.updatedAt = updatedAt
    }

    var thumbnailCoverImageUrl: String? {
        self.coverImages?.thumbnailURL(fallback: self.coverImageUrl)
    }

    var cardCoverImageUrl: String? {
        self.coverImages?.cardURL(fallback: self.coverImageUrl)
    }

    var heroCoverImageUrl: String? {
        self.coverImages?.heroURL(fallback: self.coverImageUrl)
    }
}

// MARK: - Recipe Detail

/// Full recipe details - from GET /api/v1/recipes/:id
struct RecipeDetail: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let prepTime: Int?
    let cookTime: Int?
    let favorite: Bool
    // TODO: Remove legacy coverImageUrl fallback once the backend no longer serves
    // the old cover_image_url field for older app builds.
    let coverImageUrl: String?
    let coverImages: RecipeCoverImages?
    let servings: Int?
    let ingredients: [String]
    let instructions: [String]
    let notes: String?
    let sourceUrl: String?
    let tags: [RecipeTag]
    let createdAt: Date
    let updatedAt: Date

    init(
        id: Int,
        name: String,
        prepTime: Int? = nil,
        cookTime: Int? = nil,
        favorite: Bool,
        coverImageUrl: String? = nil,
        coverImages: RecipeCoverImages? = nil,
        servings: Int? = nil,
        ingredients: [String],
        instructions: [String],
        notes: String? = nil,
        sourceUrl: String? = nil,
        tags: [RecipeTag] = [],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.favorite = favorite
        self.coverImageUrl = coverImageUrl
        self.coverImages = coverImages
        self.servings = servings
        self.ingredients = ingredients
        self.instructions = instructions
        self.notes = notes
        self.sourceUrl = sourceUrl
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var thumbnailCoverImageUrl: String? {
        self.coverImages?.thumbnailURL(fallback: self.coverImageUrl)
    }

    var cardCoverImageUrl: String? {
        self.coverImages?.cardURL(fallback: self.coverImageUrl)
    }

    var heroCoverImageUrl: String? {
        self.coverImages?.heroURL(fallback: self.coverImageUrl)
    }
}

// MARK: - Recipe Tag

struct RecipeTag: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
}
