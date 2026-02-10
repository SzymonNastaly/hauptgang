@testable import Hauptgang
import XCTest

@MainActor
final class RecipeDetailViewModelTests: XCTestCase {
    private var sut: RecipeDetailViewModel!
    private var mockRecipeService: MockRecipeService!
    private var mockRepository: MockRecipeRepository!

    override func setUp() {
        super.setUp()
        self.mockRecipeService = MockRecipeService()
        self.mockRepository = MockRecipeRepository()
        self.sut = RecipeDetailViewModel(
            recipeService: self.mockRecipeService,
            repository: self.mockRepository
        )
    }

    override func tearDown() {
        self.sut = nil
        self.mockRecipeService = nil
        self.mockRepository = nil
        super.tearDown()
    }

    // MARK: - Loading from API Tests

    func testLoadRecipe_success_updatesRecipe() async {
        let expectedRecipe = RecipeDetail.mock(id: 42, name: "Spaghetti Carbonara")
        self.mockRecipeService.fetchRecipeDetailResult = .success(expectedRecipe)

        await self.sut.loadRecipe(id: 42)

        XCTAssertEqual(self.sut.recipe?.id, 42)
        XCTAssertEqual(self.sut.recipe?.name, "Spaghetti Carbonara")
        XCTAssertFalse(self.sut.isLoading)
        XCTAssertFalse(self.sut.isRefreshing)
        XCTAssertFalse(self.sut.isOffline)
        XCTAssertNil(self.sut.errorMessage)
    }

    func testLoadRecipe_success_savesToRepository() async {
        let expectedRecipe = RecipeDetail.mock(id: 42, name: "Test Recipe")
        self.mockRecipeService.fetchRecipeDetailResult = .success(expectedRecipe)

        await self.sut.loadRecipe(id: 42)

        XCTAssertEqual(self.mockRepository.savedRecipeDetail?.id, 42)
        XCTAssertEqual(self.mockRepository.savedRecipeDetail?.name, "Test Recipe")
    }

    func testLoadRecipe_callsServiceWithCorrectId() async {
        await self.sut.loadRecipe(id: 123)

        XCTAssertTrue(self.mockRecipeService.fetchRecipeDetailCalled)
        XCTAssertEqual(self.mockRecipeService.fetchRecipeDetailCalledWithId, 123)
    }

    // MARK: - Loading State Tests

    func testLoadRecipe_noCache_setsIsLoading() async {
        XCTAssertFalse(self.sut.isLoading)
        XCTAssertFalse(self.sut.isRefreshing)

        await self.sut.loadRecipe(id: 1)

        XCTAssertFalse(self.sut.isLoading)
        XCTAssertFalse(self.sut.isRefreshing)
    }

    // MARK: - Cache Tests

    func testLoadRecipe_withCache_showsCachedDataImmediately() async {
        let cachedRecipe = self.createMockPersistedRecipe(id: 42, name: "Cached Recipe")
        self.mockRepository.cachedRecipe = cachedRecipe

        await self.sut.loadRecipe(id: 42)

        XCTAssertNotNil(self.sut.recipe)
    }

    func testLoadRecipe_withCache_refreshesFromAPI() async {
        let cachedRecipe = self.createMockPersistedRecipe(id: 42, name: "Cached Recipe")
        self.mockRepository.cachedRecipe = cachedRecipe

        let freshRecipe = RecipeDetail.mock(id: 42, name: "Updated Recipe")
        self.mockRecipeService.fetchRecipeDetailResult = .success(freshRecipe)

        await self.sut.loadRecipe(id: 42)

        XCTAssertEqual(self.sut.recipe?.name, "Updated Recipe")
    }

    // MARK: - Offline Mode Tests

    func testLoadRecipe_apiFailsWithCache_setsOfflineMode() async {
        let cachedRecipe = self.createMockPersistedRecipe(id: 42, name: "Cached Recipe")
        self.mockRepository.cachedRecipe = cachedRecipe
        self.mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)

        await self.sut.loadRecipe(id: 42)

        XCTAssertTrue(self.sut.isOffline)
        XCTAssertNotNil(self.sut.recipe)
        XCTAssertNil(self.sut.errorMessage)
    }

    func testLoadRecipe_apiFailsNoCache_showsError() async {
        self.mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)

        await self.sut.loadRecipe(id: 42)

        XCTAssertFalse(self.sut.isOffline)
        XCTAssertNil(self.sut.recipe)
        XCTAssertNotNil(self.sut.errorMessage)
        XCTAssertEqual(self.sut.errorMessage, "Failed to load recipe. Tap to retry.")
    }

    func testLoadRecipe_apiSuccess_clearsOfflineMode() async {
        let cachedRecipe = self.createMockPersistedRecipe(id: 42, name: "Cached Recipe")
        self.mockRepository.cachedRecipe = cachedRecipe
        self.mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)
        await self.sut.loadRecipe(id: 42)
        XCTAssertTrue(self.sut.isOffline)

        self.mockRecipeService.fetchRecipeDetailResult = .success(RecipeDetail.mock(id: 42))
        await self.sut.loadRecipe(id: 42)

        XCTAssertFalse(self.sut.isOffline)
    }

    // MARK: - Error Handling Tests

    func testLoadRecipe_clearsErrorOnNewLoad() async {
        self.mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)
        await self.sut.loadRecipe(id: 42)
        XCTAssertNotNil(self.sut.errorMessage)

        self.mockRecipeService.fetchRecipeDetailResult = .success(RecipeDetail.mock(id: 42))
        await self.sut.loadRecipe(id: 42)

        XCTAssertNil(self.sut.errorMessage)
    }

    // MARK: - Persistence Error Tests

    func testLoadRecipe_persistenceFailure_stillShowsAPIData() async {
        let expectedRecipe = RecipeDetail.mock(id: 42, name: "API Recipe")
        self.mockRecipeService.fetchRecipeDetailResult = .success(expectedRecipe)
        self.mockRepository.shouldThrowOnSave = true

        await self.sut.loadRecipe(id: 42)

        XCTAssertEqual(self.sut.recipe?.name, "API Recipe")
        XCTAssertFalse(self.sut.isOffline)
        XCTAssertNil(self.sut.errorMessage)
    }

    func testLoadRecipe_persistenceFailure_doesNotSetOfflineMode() async {
        self.mockRecipeService.fetchRecipeDetailResult = .success(RecipeDetail.mock(id: 42))
        self.mockRepository.shouldThrowOnSave = true

        await self.sut.loadRecipe(id: 42)

        XCTAssertFalse(self.sut.isOffline)
    }

    // MARK: - Loading Flag Cleanup Tests

    func testLoadRecipe_alwaysResetsLoadingFlags() async {
        self.mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)

        await self.sut.loadRecipe(id: 42)

        XCTAssertFalse(self.sut.isLoading)
        XCTAssertFalse(self.sut.isRefreshing)
    }

    func testLoadRecipe_withCache_alwaysResetsRefreshingFlag() async {
        let cachedRecipe = self.createMockPersistedRecipe(id: 42, name: "Cached")
        self.mockRepository.cachedRecipe = cachedRecipe
        self.mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)

        await self.sut.loadRecipe(id: 42)

        XCTAssertFalse(self.sut.isLoading)
        XCTAssertFalse(self.sut.isRefreshing)
    }

    // MARK: - Helpers

    private func createMockPersistedRecipe(id: Int, name: String) -> PersistedRecipe {
        let recipe = PersistedRecipe(from: RecipeListItem.mock(id: id, name: name))
        recipe.detailLastFetchedAt = Date()
        recipe.ingredientsJson = "[\"Ingredient 1\"]"
        recipe.instructionsJson = "[\"Step 1\"]"
        recipe.tagsJson = "[]"
        recipe.createdAt = Date()
        return recipe
    }
}
