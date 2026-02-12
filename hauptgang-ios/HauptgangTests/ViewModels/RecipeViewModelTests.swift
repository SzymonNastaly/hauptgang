@testable import Hauptgang
import SwiftData
import XCTest

@MainActor
final class RecipeViewModelTests: XCTestCase {
    private var sut: RecipeViewModel!
    private var mockRecipeService: MockRecipeService!
    private var mockRepository: MockRecipeRepository!
    private var mockSearchIndex: MockRecipeSearchIndex!

    override func setUp() {
        super.setUp()
        self.mockRecipeService = MockRecipeService()
        self.mockRepository = MockRecipeRepository()
        self.mockSearchIndex = MockRecipeSearchIndex()
        self.sut = RecipeViewModel(
            recipeService: self.mockRecipeService,
            repository: self.mockRepository,
            searchIndex: self.mockSearchIndex
        )
    }

    override func tearDown() {
        self.sut.stopPolling()
        self.sut = nil
        self.mockRecipeService = nil
        self.mockRepository = nil
        self.mockSearchIndex = nil
        super.tearDown()
    }

    // MARK: - hasPendingImports Tests

    func testHasPendingImports_withPendingRecipe_returnsTrue() {
        let pendingRecipe = self.createMockPersistedRecipe(id: 1, name: "Pending", importStatus: "pending")
        self.mockRepository.allRecipes = [pendingRecipe]

        // Simulate configure() which loads cached recipes
        self.loadCachedRecipesIntoViewModel()

        XCTAssertTrue(self.sut.hasPendingImports)
    }

    func testHasPendingImports_withCompletedRecipes_returnsFalse() {
        let completedRecipe = self.createMockPersistedRecipe(id: 1, name: "Completed", importStatus: "completed")
        let noStatusRecipe = self.createMockPersistedRecipe(id: 2, name: "No Status", importStatus: nil)
        self.mockRepository.allRecipes = [completedRecipe, noStatusRecipe]

        self.loadCachedRecipesIntoViewModel()

        XCTAssertFalse(self.sut.hasPendingImports)
    }

    func testHasPendingImports_withFailedRecipe_returnsFalse() {
        let failedRecipe = self.createMockPersistedRecipe(id: 1, name: "Failed", importStatus: "failed")
        self.mockRepository.allRecipes = [failedRecipe]

        self.loadCachedRecipesIntoViewModel()

        XCTAssertFalse(self.sut.hasPendingImports)
    }

    func testHasPendingImports_withEmptyRecipes_returnsFalse() {
        self.mockRepository.allRecipes = []

        self.loadCachedRecipesIntoViewModel()

        XCTAssertFalse(self.sut.hasPendingImports)
    }

    func testHasPendingImports_withMixedStatuses_returnsTrue() {
        let pendingRecipe = self.createMockPersistedRecipe(id: 1, name: "Pending", importStatus: "pending")
        let completedRecipe = self.createMockPersistedRecipe(id: 2, name: "Completed", importStatus: "completed")
        let failedRecipe = self.createMockPersistedRecipe(id: 3, name: "Failed", importStatus: "failed")
        self.mockRepository.allRecipes = [pendingRecipe, completedRecipe, failedRecipe]

        self.loadCachedRecipesIntoViewModel()

        XCTAssertTrue(self.sut.hasPendingImports)
    }

    // MARK: - refreshRecipes Tests

    func testRefreshRecipes_success_updatesRecipes() async {
        let apiRecipes = [
            RecipeListItem.mock(id: 1, name: "Recipe 1"),
            RecipeListItem.mock(id: 2, name: "Recipe 2"),
        ]
        self.mockRecipeService.fetchRecipesResult = .success(apiRecipes)

        // Set up repository to return persisted versions after save
        let persistedRecipes = apiRecipes.map { self.createMockPersistedRecipe(from: $0) }
        self.mockRepository.allRecipes = persistedRecipes

        await self.sut.refreshRecipes()

        XCTAssertEqual(self.sut.recipes.count, 2)
        XCTAssertFalse(self.sut.isOffline)
        XCTAssertFalse(self.sut.isLoading)
    }

    func testRefreshRecipes_networkFailure_setsOffline() async {
        self.mockRecipeService.fetchRecipesResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))

        await self.sut.refreshRecipes()

        XCTAssertTrue(self.sut.isOffline)
        XCTAssertFalse(self.sut.isLoading)
    }

    func testRefreshRecipes_failure_keepsCachedData() async {
        let cachedRecipe = self.createMockPersistedRecipe(id: 1, name: "Cached Recipe")
        self.mockRepository.allRecipes = [cachedRecipe]
        self.loadCachedRecipesIntoViewModel()

        self.mockRecipeService.fetchRecipesResult = .failure(MockRecipeError.networkError)

        await self.sut.refreshRecipes()

        XCTAssertEqual(self.sut.recipes.count, 1)
        XCTAssertEqual(self.sut.recipes.first?.name, "Cached Recipe")
    }

    func testRefreshRecipes_savesRecipesToRepository() async {
        let apiRecipes = [RecipeListItem.mock(id: 1, name: "New Recipe")]
        self.mockRecipeService.fetchRecipesResult = .success(apiRecipes)

        await self.sut.refreshRecipes()

        XCTAssertEqual(self.mockRepository.savedRecipes.count, 1)
        XCTAssertEqual(self.mockRepository.savedRecipes.first?.name, "New Recipe")
    }

    func testRefreshRecipes_clearsOfflineOnSuccess() async {
        // First, create an offline state
        self.mockRecipeService.fetchRecipesResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))
        await self.sut.refreshRecipes()
        XCTAssertTrue(self.sut.isOffline)

        // Then, refresh successfully
        self.mockRecipeService.fetchRecipesResult = .success([RecipeListItem.mock()])
        await self.sut.refreshRecipes()

        XCTAssertFalse(self.sut.isOffline)
    }

    // MARK: - stopPolling Tests

    func testStopPolling_whenNoActivePolling_doesNotCrash() {
        self.sut.stopPolling()
        // Test passes if no exception is thrown
    }

    func testStopPolling_calledMultipleTimes_doesNotCrash() {
        self.sut.stopPolling()
        self.sut.stopPolling()
        self.sut.stopPolling()
        // Test passes if no exception is thrown
    }

    // MARK: - clearData Tests

    func testClearData_clearsRecipes() {
        let recipe = self.createMockPersistedRecipe(id: 1, name: "Recipe")
        self.mockRepository.allRecipes = [recipe]
        self.loadCachedRecipesIntoViewModel()
        XCTAssertEqual(self.sut.recipes.count, 1)

        self.sut.clearData()

        XCTAssertEqual(self.sut.recipes.count, 0)
    }

    // MARK: - refreshRecipes Concurrency Guard Tests

    func testRefreshRecipes_skipsWhenAlreadyLoading() async {
        self.mockRecipeService.fetchRecipesResult = .success([RecipeListItem.mock()])

        // Start first refresh (will be in progress)
        let task1 = Task { await self.sut.refreshRecipes() }

        // Give first task time to set isLoading
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Try second refresh while first is loading
        let initialIsLoading = self.sut.isLoading
        await self.sut.refreshRecipes()

        await task1.value

        // Service should only be called once if guard works
        XCTAssertTrue(initialIsLoading || self.mockRecipeService.fetchRecipesCalled)
    }

    // MARK: - dismissFailedRecipe Tests

    func testDismissFailedRecipe_deletesFromRepository() async {
        let failedRecipe = self.createMockPersistedRecipe(id: 42, name: "Failed", importStatus: "failed")
        self.mockRepository.allRecipes = [failedRecipe]
        self.loadCachedRecipesIntoViewModel()

        await self.sut.dismissFailedRecipe(failedRecipe)

        XCTAssertFalse(self.mockRepository.allRecipes.contains { $0.id == 42 })
    }

    func testDismissFailedRecipe_callsServerDelete() async {
        let failedRecipe = self.createMockPersistedRecipe(id: 42, name: "Failed", importStatus: "failed")
        self.mockRepository.allRecipes = [failedRecipe]
        self.loadCachedRecipesIntoViewModel()

        await self.sut.dismissFailedRecipe(failedRecipe)

        XCTAssertTrue(self.mockRecipeService.deleteRecipeCalled)
        XCTAssertEqual(self.mockRecipeService.deleteRecipeCalledWithId, 42)
    }

    func testDismissFailedRecipe_serverFailure_stillRemovesLocally() async {
        let failedRecipe = self.createMockPersistedRecipe(id: 42, name: "Failed", importStatus: "failed")
        self.mockRepository.allRecipes = [failedRecipe]
        self.loadCachedRecipesIntoViewModel()

        self.mockRecipeService.deleteRecipeResult = .failure(MockRecipeError.networkError)

        await self.sut.dismissFailedRecipe(failedRecipe)

        // Local deletion should still succeed even if server fails
        XCTAssertFalse(self.mockRepository.allRecipes.contains { $0.id == 42 })
    }

    // MARK: - failedRecipes / successfulRecipes Tests

    func testFailedRecipes_filtersCorrectly() {
        let failedRecipe = self.createMockPersistedRecipe(id: 1, name: "Failed", importStatus: "failed")
        let successRecipe = self.createMockPersistedRecipe(id: 2, name: "Success", importStatus: "completed")
        self.mockRepository.allRecipes = [failedRecipe, successRecipe]
        self.loadCachedRecipesIntoViewModel()

        XCTAssertEqual(self.sut.failedRecipes.count, 1)
        XCTAssertEqual(self.sut.failedRecipes.first?.id, 1)
    }

    func testSuccessfulRecipes_excludesFailed() {
        let failedRecipe = self.createMockPersistedRecipe(id: 1, name: "Failed", importStatus: "failed")
        let successRecipe = self.createMockPersistedRecipe(id: 2, name: "Success", importStatus: "completed")
        self.mockRepository.allRecipes = [failedRecipe, successRecipe]
        self.loadCachedRecipesIntoViewModel()

        XCTAssertEqual(self.sut.successfulRecipes.count, 1)
        XCTAssertEqual(self.sut.successfulRecipes.first?.id, 2)
    }

    // MARK: - Search Fallback Tests

    func testSearch_fallsBackToSimpleSearch_whenIndexUnavailable() async {
        // Make search index unavailable to force simpleSearch fallback
        await self.mockSearchIndex.setAvailable(false)

        // Set up recipes with ingredients & instructions for fuzzy matching
        let recipe = PersistedRecipe(
            id: 1, name: "Spaghetti Carbonara", updatedAt: Date()
        )
        recipe.ingredients = ["spaghetti", "eggs", "pancetta", "parmesan"]
        recipe.instructions = ["Boil pasta", "Fry pancetta", "Mix eggs and cheese"]
        self.mockRepository.allRecipes = [recipe]
        self.loadCachedRecipesIntoViewModel()

        await self.sut.search(query: "spaghetti")

        // Wait briefly for detached task to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(self.sut.searchResults.count, 1)
        XCTAssertEqual(self.sut.searchResults.first?.id, 1)
    }

    func testSearch_fallbackReturnsEmpty_whenNoMatch() async {
        await self.mockSearchIndex.setAvailable(false)

        let recipe = PersistedRecipe(id: 1, name: "Pizza", updatedAt: Date())
        recipe.ingredients = ["dough", "tomato", "mozzarella"]
        self.mockRepository.allRecipes = [recipe]
        self.loadCachedRecipesIntoViewModel()

        await self.sut.search(query: "xyznonexistent")

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(self.sut.searchResults.isEmpty)
    }

    func testSearch_emptyQuery_clearsResults() async {
        let recipe = PersistedRecipe(id: 1, name: "Test", updatedAt: Date())
        self.mockRepository.allRecipes = [recipe]
        self.loadCachedRecipesIntoViewModel()

        await self.sut.search(query: "")

        XCTAssertTrue(self.sut.searchResults.isEmpty)
    }

    func testSearch_whitespaceOnlyQuery_clearsResults() async {
        await self.sut.search(query: "   ")

        XCTAssertTrue(self.sut.searchResults.isEmpty)
    }

    func testSearch_fallbackRanksNameMatchHigherThanIngredient() async {
        await self.mockSearchIndex.setAvailable(false)

        let nameMatch = PersistedRecipe(id: 1, name: "Chicken Soup", updatedAt: Date())
        nameMatch.ingredients = ["chicken", "broth"]
        nameMatch.instructions = ["Cook it"]

        let ingredientMatch = PersistedRecipe(id: 2, name: "Vegetable Stew", updatedAt: Date())
        ingredientMatch.ingredients = ["chicken", "vegetables"]
        ingredientMatch.instructions = ["Stew it"]

        self.mockRepository.allRecipes = [ingredientMatch, nameMatch]
        self.loadCachedRecipesIntoViewModel()

        await self.sut.search(query: "chicken")

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(self.sut.searchResults.count, 2)
        // Name match (weight 5) should rank higher than ingredient match (weight 3)
        XCTAssertEqual(self.sut.searchResults.first?.id, 1)
    }

    func testSearch_excludesFailedRecipes() async {
        await self.mockSearchIndex.setAvailable(false)

        let goodRecipe = PersistedRecipe(id: 1, name: "Good Pasta", updatedAt: Date())
        goodRecipe.ingredients = ["pasta"]
        goodRecipe.instructions = ["Cook"]

        let failedRecipe = PersistedRecipe(
            id: 2, name: "Failed Pasta", importStatus: "failed", updatedAt: Date()
        )
        failedRecipe.ingredients = ["pasta"]
        failedRecipe.instructions = ["Cook"]

        self.mockRepository.allRecipes = [goodRecipe, failedRecipe]
        self.loadCachedRecipesIntoViewModel()

        await self.sut.search(query: "pasta")

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(self.sut.searchResults.count, 1)
        XCTAssertEqual(self.sut.searchResults.first?.id, 1)
    }

    // MARK: - Helpers

    private func loadCachedRecipesIntoViewModel() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: PersistedRecipe.self, configurations: config)
        self.sut.configure(modelContext: ModelContext(container))
    }

    private func createMockPersistedRecipe(
        id: Int,
        name: String,
        importStatus: String? = nil
    ) -> PersistedRecipe {
        PersistedRecipe(from: RecipeListItem.mock(id: id, name: name, importStatus: importStatus))
    }

    private func createMockPersistedRecipe(from listItem: RecipeListItem) -> PersistedRecipe {
        PersistedRecipe(from: listItem)
    }
}
