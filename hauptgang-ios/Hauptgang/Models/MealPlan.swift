import Foundation

struct MealPlanDay: Codable, Identifiable {
    let date: String
    let selectedEntryId: Int?
    let selectedByUserId: Int?
    let selectedAt: Date?
    let entries: [MealPlanEntry]

    var id: String {
        self.date
    }

    var isSelected: Bool {
        self.selectedEntryId != nil
    }
}

struct MealPlanEntry: Codable, Identifiable {
    let id: Int
    let recipe: MealPlanRecipeSummary
    let proposedBy: MealPlanUser?
    let voteCount: Int
    let votedByCurrentUser: Bool
}

struct MealPlanRecipeSummary: Codable {
    let id: Int
    let name: String
    // swiftlint:disable:next todo
    // TODO: Remove legacy coverImageUrl fallback once the backend no longer serves
    // the old cover_image_url field for older app builds.
    let coverImageUrl: String?
    let coverImages: RecipeCoverImages?

    init(id: Int, name: String, coverImageUrl: String? = nil, coverImages: RecipeCoverImages? = nil) {
        self.id = id
        self.name = name
        self.coverImageUrl = coverImageUrl
        self.coverImages = coverImages
    }

    var thumbnailCoverImageUrl: String? {
        self.coverImages?.thumbnailURL(fallback: self.coverImageUrl)
    }
}

struct MealPlanUser: Codable {
    let id: Int
    let email: String
}

struct MealPlanAddEntryRequest: Codable {
    let recipeId: Int
}

struct MealPlanSelectRequest: Codable {
    let entryId: Int
}
