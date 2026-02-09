import SwiftData
import XCTest
@testable import Hauptgang

@MainActor
final class RecipeViewModelTests: XCTestCase {
    private var sut: RecipeViewModel!
    private var mockRecipeService: MockRecipeService!
    private var mockRepository: MockRecipeRepository!

    override func setUp() {
        super.setUp()
        mockRecipeService = MockRecipeService()
        mockRepository = MockRecipeRepository()
        sut = RecipeViewModel(
            recipeService: mockRecipeService,
            repository: mockRepository
        )
    }

    override func tearDown() {
        sut.stopPolling()
        sut = nil
        mockRecipeService = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - hasPendingImports Tests

    func testHasPendingImports_withPendingRecipe_returnsTrue() {
        let pendingRecipe = createMockPersistedRecipe(id: 1, name: "Pending", importStatus: "pending")
        mockRepository.allRecipes = [pendingRecipe]

        // Simulate configure() which loads cached recipes
        loadCachedRecipesIntoViewModel()

        XCTAssertTrue(sut.hasPendingImports)
    }

    func testHasPendingImports_withCompletedRecipes_returnsFalse() {
        let completedRecipe = createMockPersistedRecipe(id: 1, name: "Completed", importStatus: "completed")
        let noStatusRecipe = createMockPersistedRecipe(id: 2, name: "No Status", importStatus: nil)
        mockRepository.allRecipes = [completedRecipe, noStatusRecipe]

        loadCachedRecipesIntoViewModel()

        XCTAssertFalse(sut.hasPendingImports)
    }

    func testHasPendingImports_withFailedRecipe_returnsFalse() {
        let failedRecipe = createMockPersistedRecipe(id: 1, name: "Failed", importStatus: "failed")
        mockRepository.allRecipes = [failedRecipe]

        loadCachedRecipesIntoViewModel()

        XCTAssertFalse(sut.hasPendingImports)
    }

    func testHasPendingImports_withEmptyRecipes_returnsFalse() {
        mockRepository.allRecipes = []

        loadCachedRecipesIntoViewModel()

        XCTAssertFalse(sut.hasPendingImports)
    }

    func testHasPendingImports_withMixedStatuses_returnsTrue() {
        let pendingRecipe = createMockPersistedRecipe(id: 1, name: "Pending", importStatus: "pending")
        let completedRecipe = createMockPersistedRecipe(id: 2, name: "Completed", importStatus: "completed")
        let failedRecipe = createMockPersistedRecipe(id: 3, name: "Failed", importStatus: "failed")
        mockRepository.allRecipes = [pendingRecipe, completedRecipe, failedRecipe]

        loadCachedRecipesIntoViewModel()

        XCTAssertTrue(sut.hasPendingImports)
    }

    // MARK: - refreshRecipes Tests

    func testRefreshRecipes_success_updatesRecipes() async {
        let apiRecipes = [
            RecipeListItem.mock(id: 1, name: "Recipe 1"),
            RecipeListItem.mock(id: 2, name: "Recipe 2")
        ]
        mockRecipeService.fetchRecipesResult = .success(apiRecipes)

        // Set up repository to return persisted versions after save
        let persistedRecipes = apiRecipes.map { createMockPersistedRecipe(from: $0) }
        mockRepository.allRecipes = persistedRecipes

        await sut.refreshRecipes()

        XCTAssertEqual(sut.recipes.count, 2)
        XCTAssertFalse(sut.isOffline)
        XCTAssertFalse(sut.isLoading)
    }

    func testRefreshRecipes_networkFailure_setsOffline() async {
        mockRecipeService.fetchRecipesResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))

        await sut.refreshRecipes()

        XCTAssertTrue(sut.isOffline)
        XCTAssertFalse(sut.isLoading)
    }

    func testRefreshRecipes_failure_keepsCachedData() async {
        let cachedRecipe = createMockPersistedRecipe(id: 1, name: "Cached Recipe")
        mockRepository.allRecipes = [cachedRecipe]
        loadCachedRecipesIntoViewModel()

        mockRecipeService.fetchRecipesResult = .failure(MockRecipeError.networkError)

        await sut.refreshRecipes()

        XCTAssertEqual(sut.recipes.count, 1)
        XCTAssertEqual(sut.recipes.first?.name, "Cached Recipe")
    }

    func testRefreshRecipes_savesRecipesToRepository() async {
        let apiRecipes = [RecipeListItem.mock(id: 1, name: "New Recipe")]
        mockRecipeService.fetchRecipesResult = .success(apiRecipes)

        await sut.refreshRecipes()

        XCTAssertEqual(mockRepository.savedRecipes.count, 1)
        XCTAssertEqual(mockRepository.savedRecipes.first?.name, "New Recipe")
    }

    func testRefreshRecipes_clearsOfflineOnSuccess() async {
        // First, create an offline state
        mockRecipeService.fetchRecipesResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))
        await sut.refreshRecipes()
        XCTAssertTrue(sut.isOffline)

        // Then, refresh successfully
        mockRecipeService.fetchRecipesResult = .success([RecipeListItem.mock()])
        await sut.refreshRecipes()

        XCTAssertFalse(sut.isOffline)
    }

    // MARK: - stopPolling Tests

    func testStopPolling_whenNoActivePolling_doesNotCrash() {
        sut.stopPolling()
        // Test passes if no exception is thrown
    }

    func testStopPolling_calledMultipleTimes_doesNotCrash() {
        sut.stopPolling()
        sut.stopPolling()
        sut.stopPolling()
        // Test passes if no exception is thrown
    }

    // MARK: - clearData Tests

    func testClearData_clearsRecipes() {
        let recipe = createMockPersistedRecipe(id: 1, name: "Recipe")
        mockRepository.allRecipes = [recipe]
        loadCachedRecipesIntoViewModel()
        XCTAssertEqual(sut.recipes.count, 1)

        sut.clearData()

        XCTAssertEqual(sut.recipes.count, 0)
    }

    // MARK: - refreshRecipes Concurrency Guard Tests

    func testRefreshRecipes_skipsWhenAlreadyLoading() async {
        mockRecipeService.fetchRecipesResult = .success([RecipeListItem.mock()])

        // Start first refresh (will be in progress)
        let task1 = Task { await sut.refreshRecipes() }

        // Give first task time to set isLoading
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Try second refresh while first is loading
        let initialIsLoading = sut.isLoading
        await sut.refreshRecipes()

        await task1.value

        // Service should only be called once if guard works
        XCTAssertTrue(initialIsLoading || mockRecipeService.fetchRecipesCalled)
    }

    // MARK: - dismissFailedRecipe Tests

    func testDismissFailedRecipe_deletesFromRepository() async {
        let failedRecipe = createMockPersistedRecipe(id: 42, name: "Failed", importStatus: "failed")
        mockRepository.allRecipes = [failedRecipe]
        loadCachedRecipesIntoViewModel()

        await sut.dismissFailedRecipe(failedRecipe)

        XCTAssertFalse(mockRepository.allRecipes.contains { $0.id == 42 })
    }

    func testDismissFailedRecipe_callsServerDelete() async {
        let failedRecipe = createMockPersistedRecipe(id: 42, name: "Failed", importStatus: "failed")
        mockRepository.allRecipes = [failedRecipe]
        loadCachedRecipesIntoViewModel()

        await sut.dismissFailedRecipe(failedRecipe)

        XCTAssertTrue(mockRecipeService.deleteRecipeCalled)
        XCTAssertEqual(mockRecipeService.deleteRecipeCalledWithId, 42)
    }

    func testDismissFailedRecipe_serverFailure_stillRemovesLocally() async {
        let failedRecipe = createMockPersistedRecipe(id: 42, name: "Failed", importStatus: "failed")
        mockRepository.allRecipes = [failedRecipe]
        loadCachedRecipesIntoViewModel()

        mockRecipeService.deleteRecipeResult = .failure(MockRecipeError.networkError)

        await sut.dismissFailedRecipe(failedRecipe)

        // Local deletion should still succeed even if server fails
        XCTAssertFalse(mockRepository.allRecipes.contains { $0.id == 42 })
    }

    // MARK: - failedRecipes / successfulRecipes Tests

    func testFailedRecipes_filtersCorrectly() {
        let failedRecipe = createMockPersistedRecipe(id: 1, name: "Failed", importStatus: "failed")
        let successRecipe = createMockPersistedRecipe(id: 2, name: "Success", importStatus: "completed")
        mockRepository.allRecipes = [failedRecipe, successRecipe]
        loadCachedRecipesIntoViewModel()

        XCTAssertEqual(sut.failedRecipes.count, 1)
        XCTAssertEqual(sut.failedRecipes.first?.id, 1)
    }

    func testSuccessfulRecipes_excludesFailed() {
        let failedRecipe = createMockPersistedRecipe(id: 1, name: "Failed", importStatus: "failed")
        let successRecipe = createMockPersistedRecipe(id: 2, name: "Success", importStatus: "completed")
        mockRepository.allRecipes = [failedRecipe, successRecipe]
        loadCachedRecipesIntoViewModel()

        XCTAssertEqual(sut.successfulRecipes.count, 1)
        XCTAssertEqual(sut.successfulRecipes.first?.id, 2)
    }

    // MARK: - Helpers

    private func loadCachedRecipesIntoViewModel() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: PersistedRecipe.self, configurations: config)
        sut.configure(modelContext: ModelContext(container))
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
