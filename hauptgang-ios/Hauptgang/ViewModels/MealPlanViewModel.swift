import Foundation
import os
import SwiftData
import SwiftUI

@MainActor @Observable
final class MealPlanViewModel {
    private(set) var todayEntries: [PersistedMealPlanEntry] = []
    private(set) var tomorrowEntries: [PersistedMealPlanEntry] = []
    private(set) var todayDay: PersistedMealPlanDay?
    private(set) var tomorrowDay: PersistedMealPlanDay?
    private(set) var isSyncing = false
    private(set) var isOffline = false
    private(set) var isSelecting = false
    var didReceiveForbidden = false

    var todayDateString: String {
        Self.dateString(for: Date())
    }

    var tomorrowDateString: String {
        Self.dateString(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
    }

    private var activeCookbookId: Int?
    private let repository: MealPlanRepositoryProtocol
    private let service: MealPlanServiceProtocol
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "MealPlanViewModel")

    init(
        repository: MealPlanRepositoryProtocol? = nil,
        service: MealPlanServiceProtocol = MealPlanService.shared
    ) {
        self.repository = repository ?? MealPlanRepository()
        self.service = service
    }

    func configure(modelContext: ModelContext) {
        self.repository.configure(modelContext: modelContext)
        self.loadCachedData()
    }

    // MARK: - Refresh

    func refresh(cookbookId: Int) async {
        guard !self.isSyncing else { return }

        self.activeCookbookId = cookbookId
        self.isSyncing = true
        self.isOffline = false

        await self.syncPendingEntries(cookbookId: cookbookId)

        do {
            let plans = try await service.fetchMealPlans(
                cookbookId: cookbookId,
                from: self.todayDateString,
                to: self.tomorrowDateString
            )
            try self.repository.saveDays(plans, cookbookId: cookbookId)
            self.loadCachedData()
        } catch {
            self.logger.error("Failed to refresh meal plans: \(error.localizedDescription)")
            if let apiError = error as? APIError {
                switch apiError {
                case .networkError:
                    self.isOffline = true
                case .forbidden:
                    self.didReceiveForbidden = true
                default:
                    break
                }
            }
        }

        self.isSyncing = false
    }

    // MARK: - Add Entry

    func addEntry(cookbookId: Int, date: String, recipe: PersistedRecipe) {
        do {
            try self.repository.addLocalEntry(
                cookbookId: cookbookId,
                date: date,
                recipeId: recipe.id,
                recipeName: recipe.name,
                recipeCoverImageUrl: recipe.coverImageUrl
            )
            self.loadCachedData()
            Task { await self.syncAddEntry(cookbookId: cookbookId, date: date, recipeId: recipe.id) }
        } catch {
            self.logger.error("Failed to add entry locally: \(error.localizedDescription)")
        }
    }

    private func syncAddEntry(cookbookId: Int, date: String, recipeId: Int) async {
        do {
            let updatedDay = try await service.addEntry(cookbookId: cookbookId, date: date, recipeId: recipeId)
            try self.repository.saveDays([updatedDay], cookbookId: cookbookId)
            self.loadCachedData()
        } catch {
            self.logger.error("Failed to sync add entry: \(error.localizedDescription)")
            if let apiError = error as? APIError {
                switch apiError {
                case .unprocessableEntity, .notFound:
                    try? self.repository.deletePendingEntry(cookbookId: cookbookId, date: date, recipeId: recipeId)
                    self.loadCachedData()
                case .networkError:
                    self.isOffline = true
                default:
                    break
                }
            }
        }
    }

    // MARK: - Delete Entry

    func deleteEntry(_ entry: PersistedMealPlanEntry, cookbookId: Int) {
        guard let serverId = entry.serverId else {
            try? self.repository.deletePendingEntry(
                cookbookId: entry.cookbookId,
                date: entry.date,
                recipeId: entry.recipeId
            )
            self.loadCachedData()
            return
        }

        guard !self.isOffline else { return }

        Task {
            do {
                try await self.service.deleteEntry(id: serverId)
                try? self.repository.deletePendingEntry(
                    cookbookId: entry.cookbookId,
                    date: entry.date,
                    recipeId: entry.recipeId
                )
                self.loadCachedData()
            } catch {
                self.logger.error("Failed to delete entry from server: \(error.localizedDescription)")
                await self.refresh(cookbookId: cookbookId)
            }
        }
    }

    // MARK: - Vote

    func toggleVote(entry: PersistedMealPlanEntry, cookbookId: Int) {
        guard let serverId = entry.serverId else { return }

        let wasVoted = entry.votedByCurrentUser
        entry.votedByCurrentUser = !wasVoted
        entry.voteCount += wasVoted ? -1 : 1

        Task {
            do {
                let updatedDay: MealPlanDay = if wasVoted {
                    try await self.service.unvote(entryId: serverId)
                } else {
                    try await self.service.vote(entryId: serverId)
                }
                try self.repository.saveDays([updatedDay], cookbookId: cookbookId)
                self.loadCachedData()
            } catch {
                self.logger.error("Failed to toggle vote: \(error.localizedDescription)")
                entry.votedByCurrentUser = wasVoted
                entry.voteCount += wasVoted ? 1 : -1
            }
        }
    }

    // MARK: - Select / Deselect

    func selectEntry(_ entry: PersistedMealPlanEntry, cookbookId: Int) {
        guard let serverId = entry.serverId else { return }
        self.isSelecting = true

        Task {
            do {
                let updatedDay = try await service.select(cookbookId: cookbookId, date: entry.date, entryId: serverId)
                try self.repository.saveDays([updatedDay], cookbookId: cookbookId)
                self.loadCachedData()
            } catch {
                self.logger.error("Failed to select entry: \(error.localizedDescription)")
            }
            self.isSelecting = false
        }
    }

    func deselectDay(date: String, cookbookId: Int) {
        self.isSelecting = true

        Task {
            do {
                let updatedDay = try await service.deselect(cookbookId: cookbookId, date: date)
                try self.repository.saveDays([updatedDay], cookbookId: cookbookId)
                self.loadCachedData()
            } catch {
                self.logger.error("Failed to deselect: \(error.localizedDescription)")
            }
            self.isSelecting = false
        }
    }

    // MARK: - Reset

    func resetForCookbookSwitch() {
        self.activeCookbookId = nil
        self.todayEntries = []
        self.tomorrowEntries = []
        self.todayDay = nil
        self.tomorrowDay = nil
        self.isSyncing = false
        self.isOffline = false
    }

    func clearData() {
        do {
            try self.repository.clearAll()
            self.todayEntries = []
            self.tomorrowEntries = []
            self.todayDay = nil
            self.tomorrowDay = nil
        } catch {
            self.logger.error("Failed to clear meal plan data: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func loadCachedData() {
        guard let cookbookId = self.activeCookbookId else { return }

        do {
            let dates = [self.todayDateString, self.tomorrowDateString]
            let days = try self.repository.getDays(cookbookId: cookbookId, dates: dates)

            self.todayDay = days.first { $0.date == self.todayDateString }
            self.tomorrowDay = days.first { $0.date == self.tomorrowDateString }

            self.todayEntries = try self.repository.getEntries(cookbookId: cookbookId, date: self.todayDateString)
                .sorted { $0.voteCount > $1.voteCount }
            self.tomorrowEntries = try self.repository.getEntries(cookbookId: cookbookId, date: self.tomorrowDateString)
                .sorted { $0.voteCount > $1.voteCount }
        } catch {
            self.logger.error("Failed to load cached meal plan data: \(error.localizedDescription)")
        }
    }

    private func syncPendingEntries(cookbookId: Int) async {
        do {
            let pending = try repository.getPendingEntries(cookbookId: cookbookId)
            for entry in pending {
                do {
                    let updatedDay = try await service.addEntry(
                        cookbookId: cookbookId,
                        date: entry.date,
                        recipeId: entry.recipeId
                    )
                    try self.repository.saveDays([updatedDay], cookbookId: cookbookId)
                } catch {
                    self.logger.error("Failed to sync pending entry: \(error.localizedDescription)")
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .unprocessableEntity, .notFound:
                            try? self.repository.deletePendingEntry(
                                cookbookId: cookbookId,
                                date: entry.date,
                                recipeId: entry.recipeId
                            )
                        case .networkError:
                            self.isOffline = true
                            return
                        default:
                            break
                        }
                    }
                }
            }
            self.loadCachedData()
        } catch {
            self.logger.error("Failed to get pending entries: \(error.localizedDescription)")
        }
    }

    static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    static func displayDate(for dateString: String) -> String {
        let today = Self.dateString(for: Date())
        let tomorrow = Self.dateString(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)

        if dateString == today { return "Today" }
        if dateString == tomorrow { return "Tomorrow" }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return dateString
    }
}
