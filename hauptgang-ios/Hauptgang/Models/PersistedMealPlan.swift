import Foundation
import SwiftData

enum MealPlanEntrySyncState: String, Codable {
    case pendingCreate = "pending_create"
    case synced
}

@Model
final class PersistedMealPlanDay {
    @Attribute(.unique) var scopedDate: String
    var cookbookId: Int
    var date: String
    var selectedEntryId: Int?
    var selectedByUserId: Int?
    var selectedAt: Date?

    var isSelected: Bool { selectedEntryId != nil }

    init(
        cookbookId: Int,
        date: String,
        selectedEntryId: Int? = nil,
        selectedByUserId: Int? = nil,
        selectedAt: Date? = nil
    ) {
        self.scopedDate = "\(cookbookId)|\(date)"
        self.cookbookId = cookbookId
        self.date = date
        self.selectedEntryId = selectedEntryId
        self.selectedByUserId = selectedByUserId
        self.selectedAt = selectedAt
    }
}

@Model
final class PersistedMealPlanEntry {
    @Attribute(.unique) var scopedId: String
    var cookbookId: Int
    var date: String
    var serverId: Int?
    var recipeId: Int
    var recipeName: String
    var recipeCoverImageUrl: String?
    var proposedByEmail: String?
    var voteCount: Int
    var votedByCurrentUser: Bool
    var syncStateRaw: String

    var syncState: MealPlanEntrySyncState {
        get { MealPlanEntrySyncState(rawValue: self.syncStateRaw) ?? .synced }
        set { self.syncStateRaw = newValue.rawValue }
    }

    init(
        cookbookId: Int,
        date: String,
        serverId: Int? = nil,
        recipeId: Int,
        recipeName: String,
        recipeCoverImageUrl: String? = nil,
        proposedByEmail: String? = nil,
        voteCount: Int = 0,
        votedByCurrentUser: Bool = false,
        syncState: MealPlanEntrySyncState = .synced
    ) {
        self.scopedId = "\(cookbookId)|\(date)|\(recipeId)"
        self.cookbookId = cookbookId
        self.date = date
        self.serverId = serverId
        self.recipeId = recipeId
        self.recipeName = recipeName
        self.recipeCoverImageUrl = recipeCoverImageUrl
        self.proposedByEmail = proposedByEmail
        self.voteCount = voteCount
        self.votedByCurrentUser = votedByCurrentUser
        self.syncStateRaw = syncState.rawValue
    }
}
