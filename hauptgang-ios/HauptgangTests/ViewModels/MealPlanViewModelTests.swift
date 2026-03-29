import Foundation
@testable import Hauptgang
import SwiftData
import Testing

@MainActor
struct MealPlanViewModelTests {
    private let cookbookId = 1

    private func makeMealPlanDay(
        date: String? = nil,
        entries: [MealPlanEntry] = [],
        selectedEntryId: Int? = nil
    ) -> MealPlanDay {
        MealPlanDay(
            date: date ?? MealPlanViewModel.dateString(for: Date()),
            selectedEntryId: selectedEntryId,
            selectedByUserId: nil,
            selectedAt: nil,
            entries: entries
        )
    }

    private func makeEntry(
        id: Int = 1,
        recipeId: Int = 100,
        recipeName: String = "Test Recipe",
        voteCount: Int = 0,
        votedByCurrentUser: Bool = false
    ) -> MealPlanEntry {
        MealPlanEntry(
            id: id,
            recipe: MealPlanRecipeSummary(id: recipeId, name: recipeName, coverImageUrl: nil),
            proposedBy: nil,
            voteCount: voteCount,
            votedByCurrentUser: votedByCurrentUser
        )
    }

    private func makePersistedEntry(
        cookbookId: Int = 1,
        date: String? = nil,
        serverId: Int? = 1,
        recipeId: Int = 100,
        recipeName: String = "Test Recipe",
        voteCount: Int = 0,
        votedByCurrentUser: Bool = false,
        syncState: MealPlanEntrySyncState = .synced
    ) -> PersistedMealPlanEntry {
        PersistedMealPlanEntry(
            cookbookId: cookbookId,
            date: date ?? MealPlanViewModel.dateString(for: Date()),
            serverId: serverId,
            recipeId: recipeId,
            recipeName: recipeName,
            voteCount: voteCount,
            votedByCurrentUser: votedByCurrentUser,
            syncState: syncState
        )
    }

    private func makeVM(
        repository: MockMealPlanRepository = MockMealPlanRepository(),
        service: MockMealPlanService = MockMealPlanService()
    ) -> (MealPlanViewModel, MockMealPlanRepository, MockMealPlanService) {
        let vm = MealPlanViewModel(repository: repository, service: service)
        return (vm, repository, service)
    }

    // MARK: - Refresh

    @Test func refresh_fetchesMealPlansAndSavesToRepo() async {
        let (vm, repo, service) = self.makeVM()
        let entry = self.makeEntry()
        service.fetchResult = [self.makeMealPlanDay(entries: [entry])]

        await vm.refresh(cookbookId: self.cookbookId)

        #expect(service.fetchCallCount == 1)
        #expect(repo.savedDays.count == 1)
        #expect(repo.savedDays.first?.count == 1)
        #expect(vm.isSyncing == false)
    }

    @Test func refresh_setsOfflineOnNetworkError() async {
        let (vm, _, service) = self.makeVM()
        service.shouldThrow = true
        service.errorToThrow = APIError.networkError(URLError(.notConnectedToInternet))

        await vm.refresh(cookbookId: self.cookbookId)

        #expect(vm.isOffline == true)
        #expect(vm.isSyncing == false)
    }

    @Test func refresh_setsForbiddenOnForbiddenError() async {
        let (vm, _, service) = self.makeVM()
        service.shouldThrow = true
        service.errorToThrow = APIError.forbidden

        await vm.refresh(cookbookId: self.cookbookId)

        #expect(vm.didReceiveForbidden == true)
    }

    @Test func refresh_doesNotRunConcurrently() async {
        let (vm, _, service) = self.makeVM()
        service.fetchResult = []

        await vm.refresh(cookbookId: self.cookbookId)
        #expect(service.fetchCallCount == 1)
    }

    @Test func refresh_syncsPendingEntriesFirst() async {
        let repo = MockMealPlanRepository()
        let service = MockMealPlanService()
        let pendingEntry = self.makePersistedEntry(syncState: .pendingCreate)
        repo.pendingEntries = [pendingEntry]
        service.addEntryResult = self.makeMealPlanDay(entries: [self.makeEntry()])
        service.fetchResult = []

        let vm = MealPlanViewModel(repository: repo, service: service)
        await vm.refresh(cookbookId: self.cookbookId)

        #expect(service.addEntryCallCount == 1)
    }

    // MARK: - Add Entry

    @Test func addEntry_addsLocalEntryAndSyncs() async {
        let repo = MockMealPlanRepository()
        let service = MockMealPlanService()
        let entry = self.makeEntry()
        service.addEntryResult = self.makeMealPlanDay(entries: [entry])

        let vm = MealPlanViewModel(repository: repo, service: service)
        let recipe = self.makeTestRecipe()

        vm.addEntry(cookbookId: self.cookbookId, date: MealPlanViewModel.dateString(for: Date()), recipe: recipe)

        #expect(repo.addedLocalEntries.count == 1)
        #expect(repo.addedLocalEntries.first?.recipeId == recipe.id)

        // Wait for background sync
        try? await Task.sleep(for: .milliseconds(100))
        #expect(service.addEntryCallCount == 1)
    }

    // MARK: - Delete Entry

    @Test func deleteEntry_deletesPendingEntryLocally() {
        let (vm, repo, service) = self.makeVM()
        let entry = self.makePersistedEntry(serverId: nil, syncState: .pendingCreate)

        vm.deleteEntry(entry, cookbookId: self.cookbookId)

        #expect(repo.deletedPendingEntries.count == 1)
        #expect(service.deleteEntryCallCount == 0)
    }

    @Test func deleteEntry_deletesSyncedEntryFromServer() async {
        let (vm, repo, service) = self.makeVM()
        let entry = self.makePersistedEntry(serverId: 42)

        vm.deleteEntry(entry, cookbookId: self.cookbookId)

        #expect(repo.deletedPendingEntries.isEmpty)

        try? await Task.sleep(for: .milliseconds(100))
        #expect(service.deleteEntryCallCount == 1)
        #expect(service.lastDeletedEntryId == 42)
        #expect(repo.deletedPendingEntries.count == 1)
    }

    @Test func deleteEntry_ignoresSyncedEntryWhileOffline() async {
        let (vm, repo, service) = self.makeVM()
        let entry = self.makePersistedEntry(serverId: 42)

        service.shouldThrow = true
        service.errorToThrow = APIError.networkError(URLError(.notConnectedToInternet))

        await vm.refresh(cookbookId: self.cookbookId)
        vm.deleteEntry(entry, cookbookId: self.cookbookId)

        try? await Task.sleep(for: .milliseconds(50))
        #expect(service.deleteEntryCallCount == 0)
        #expect(repo.deletedPendingEntries.isEmpty)
    }

    @Test func addEntry_removesPendingEntryOnNotFound() async {
        let repo = MockMealPlanRepository()
        let service = MockMealPlanService()
        service.shouldThrow = true
        service.errorToThrow = APIError.notFound

        let vm = MealPlanViewModel(repository: repo, service: service)
        let recipe = self.makeTestRecipe()
        let date = MealPlanViewModel.dateString(for: Date())

        vm.addEntry(cookbookId: self.cookbookId, date: date, recipe: recipe)

        try? await Task.sleep(for: .milliseconds(100))
        #expect(repo.deletedPendingEntries.count == 1)
        #expect(repo.deletedPendingEntries.first?.recipeId == recipe.id)
    }

    // MARK: - Toggle Vote

    @Test func toggleVote_optimisticallyUpdatesUI() {
        let (vm, _, _) = self.makeVM()
        let entry = self.makePersistedEntry(serverId: 10, voteCount: 0, votedByCurrentUser: false)

        vm.toggleVote(entry: entry, cookbookId: self.cookbookId)

        #expect(entry.votedByCurrentUser == true)
        #expect(entry.voteCount == 1)
    }

    @Test func toggleVote_revertsOnError() async {
        let service = MockMealPlanService()
        service.shouldThrow = true
        let (vm, _, _) = self.makeVM(service: service)
        let entry = self.makePersistedEntry(serverId: 10, voteCount: 1, votedByCurrentUser: true)

        vm.toggleVote(entry: entry, cookbookId: self.cookbookId)

        // Optimistic update
        #expect(entry.votedByCurrentUser == false)
        #expect(entry.voteCount == 0)

        // Wait for error handler to revert
        try? await Task.sleep(for: .milliseconds(100))
        #expect(entry.votedByCurrentUser == true)
        #expect(entry.voteCount == 1)
    }

    @Test func toggleVote_ignoresEntryWithoutServerId() async {
        let (vm, _, service) = self.makeVM()
        let entry = self.makePersistedEntry(serverId: nil)

        vm.toggleVote(entry: entry, cookbookId: self.cookbookId)

        try? await Task.sleep(for: .milliseconds(50))
        #expect(service.voteCallCount == 0)
        #expect(service.unvoteCallCount == 0)
    }

    // MARK: - Select / Deselect

    @Test func selectEntry_callsServiceAndSaves() async {
        let service = MockMealPlanService()
        let entry = self.makeEntry(id: 5)
        service.selectResult = self.makeMealPlanDay(entries: [entry], selectedEntryId: 5)
        let (vm, repo, _) = self.makeVM(service: service)
        let persistedEntry = self.makePersistedEntry(serverId: 5)

        vm.selectEntry(persistedEntry, cookbookId: self.cookbookId)

        #expect(vm.isSelecting == true)

        try? await Task.sleep(for: .milliseconds(100))
        #expect(service.selectCallCount == 1)
        #expect(service.lastSelectedEntryId == 5)
        #expect(repo.savedDays.count == 1)
        #expect(vm.isSelecting == false)
    }

    @Test func selectEntry_ignoresEntryWithoutServerId() async {
        let (vm, _, service) = self.makeVM()
        let entry = self.makePersistedEntry(serverId: nil)

        vm.selectEntry(entry, cookbookId: self.cookbookId)

        try? await Task.sleep(for: .milliseconds(50))
        #expect(service.selectCallCount == 0)
    }

    @Test func deselectDay_callsServiceAndSaves() async {
        let service = MockMealPlanService()
        service.deselectResult = self.makeMealPlanDay()
        let (vm, repo, _) = self.makeVM(service: service)
        let date = MealPlanViewModel.dateString(for: Date())

        vm.deselectDay(date: date, cookbookId: self.cookbookId)

        try? await Task.sleep(for: .milliseconds(100))
        #expect(service.deselectCallCount == 1)
        #expect(repo.savedDays.count == 1)
        #expect(vm.isSelecting == false)
    }

    // MARK: - Reset

    @Test func resetForCookbookSwitch_clearsState() {
        let (vm, _, _) = self.makeVM()

        vm.resetForCookbookSwitch()

        #expect(vm.todayEntries.isEmpty)
        #expect(vm.tomorrowEntries.isEmpty)
        #expect(vm.todayDay == nil)
        #expect(vm.tomorrowDay == nil)
        #expect(vm.isSyncing == false)
        #expect(vm.isOffline == false)
    }

    @Test func clearData_clearsRepoAndState() {
        let repo = MockMealPlanRepository()
        let vm = MealPlanViewModel(repository: repo, service: MockMealPlanService())

        vm.clearData()

        #expect(vm.todayEntries.isEmpty)
        #expect(vm.tomorrowEntries.isEmpty)
    }

    // MARK: - Date Helpers

    @Test func dateString_formatsCorrectly() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let today = Date()
        let expected = formatter.string(from: today)

        #expect(MealPlanViewModel.dateString(for: today) == expected)
    }

    @Test func displayDate_returnsTodayForToday() {
        let todayStr = MealPlanViewModel.dateString(for: Date())
        #expect(MealPlanViewModel.displayDate(for: todayStr) == "Today")
    }

    @Test func displayDate_returnsTomorrowForTomorrow() throws {
        let tomorrowStr = try MealPlanViewModel.dateString(for: #require(Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Date()
        )))
        #expect(MealPlanViewModel.displayDate(for: tomorrowStr) == "Tomorrow")
    }

    @Test func displayDate_returnsFormattedDateForOtherDates() {
        let result = MealPlanViewModel.displayDate(for: "2025-06-15")
        #expect(result != "Today")
        #expect(result != "Tomorrow")
        #expect(!result.isEmpty)
    }

    // MARK: - Helpers

    private func makeTestRecipe() -> PersistedRecipe {
        PersistedRecipe(
            id: 100,
            cookbookId: self.cookbookId,
            name: "Test Recipe",
            favorite: false,
            updatedAt: Date(),
            lastFetchedAt: Date()
        )
    }
}
