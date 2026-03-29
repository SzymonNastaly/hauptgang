import Foundation

struct MealPlanDay: Codable, Identifiable, Sendable {
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

struct MealPlanEntry: Codable, Identifiable, Sendable {
    let id: Int
    let recipe: MealPlanRecipeSummary
    let proposedBy: MealPlanUser?
    let voteCount: Int
    let votedByCurrentUser: Bool
}

struct MealPlanRecipeSummary: Codable, Sendable {
    let id: Int
    let name: String
    let coverImageUrl: String?
}

struct MealPlanUser: Codable, Sendable {
    let id: Int
    let email: String
}

struct MealPlanAddEntryRequest: Codable, Sendable {
    let recipeId: Int
}

struct MealPlanSelectRequest: Codable, Sendable {
    let entryId: Int
}
