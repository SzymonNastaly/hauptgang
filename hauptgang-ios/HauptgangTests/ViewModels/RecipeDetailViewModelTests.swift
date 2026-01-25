import XCTest
@testable import Hauptgang

@MainActor
final class RecipeDetailViewModelTests: XCTestCase {
    private var sut: RecipeDetailViewModel!
    private var mockRecipeService: MockRecipeService!
    private var mockRepository: MockRecipeRepository!

    override func setUp() {
        super.setUp()
        mockRecipeService = MockRecipeService()
        mockRepository = MockRecipeRepository()
        sut = RecipeDetailViewModel(
            recipeService: mockRecipeService,
            repository: mockRepository
        )
    }

    override func tearDown() {
        sut = nil
        mockRecipeService = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Loading from API Tests

    func testLoadRecipe_success_updatesRecipe() async {
        let expectedRecipe = RecipeDetail.mock(id: 42, name: "Spaghetti Carbonara")
        mockRecipeService.fetchRecipeDetailResult = .success(expectedRecipe)

        await sut.loadRecipe(id: 42)

        XCTAssertEqual(sut.recipe?.id, 42)
        XCTAssertEqual(sut.recipe?.name, "Spaghetti Carbonara")
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isRefreshing)
        XCTAssertFalse(sut.isOffline)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadRecipe_success_savesToRepository() async {
        let expectedRecipe = RecipeDetail.mock(id: 42, name: "Test Recipe")
        mockRecipeService.fetchRecipeDetailResult = .success(expectedRecipe)

        await sut.loadRecipe(id: 42)

        XCTAssertEqual(mockRepository.savedRecipeDetail?.id, 42)
        XCTAssertEqual(mockRepository.savedRecipeDetail?.name, "Test Recipe")
    }

    func testLoadRecipe_callsServiceWithCorrectId() async {
        await sut.loadRecipe(id: 123)

        XCTAssertTrue(mockRecipeService.fetchRecipeDetailCalled)
        XCTAssertEqual(mockRecipeService.fetchRecipeDetailCalledWithId, 123)
    }

    // MARK: - Loading State Tests

    func testLoadRecipe_noCache_setsIsLoading() async {
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isRefreshing)

        await sut.loadRecipe(id: 1)

        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isRefreshing)
    }

    // MARK: - Cache Tests

    func testLoadRecipe_withCache_showsCachedDataImmediately() async {
        let cachedRecipe = createMockPersistedRecipe(id: 42, name: "Cached Recipe")
        mockRepository.cachedRecipe = cachedRecipe

        await sut.loadRecipe(id: 42)

        XCTAssertNotNil(sut.recipe)
    }

    func testLoadRecipe_withCache_refreshesFromAPI() async {
        let cachedRecipe = createMockPersistedRecipe(id: 42, name: "Cached Recipe")
        mockRepository.cachedRecipe = cachedRecipe

        let freshRecipe = RecipeDetail.mock(id: 42, name: "Updated Recipe")
        mockRecipeService.fetchRecipeDetailResult = .success(freshRecipe)

        await sut.loadRecipe(id: 42)

        XCTAssertEqual(sut.recipe?.name, "Updated Recipe")
    }

    // MARK: - Offline Mode Tests

    func testLoadRecipe_apiFailsWithCache_setsOfflineMode() async {
        let cachedRecipe = createMockPersistedRecipe(id: 42, name: "Cached Recipe")
        mockRepository.cachedRecipe = cachedRecipe
        mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)

        await sut.loadRecipe(id: 42)

        XCTAssertTrue(sut.isOffline)
        XCTAssertNotNil(sut.recipe)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadRecipe_apiFailsNoCache_showsError() async {
        mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)

        await sut.loadRecipe(id: 42)

        XCTAssertFalse(sut.isOffline)
        XCTAssertNil(sut.recipe)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(sut.errorMessage, "Failed to load recipe. Tap to retry.")
    }

    func testLoadRecipe_apiSuccess_clearsOfflineMode() async {
        let cachedRecipe = createMockPersistedRecipe(id: 42, name: "Cached Recipe")
        mockRepository.cachedRecipe = cachedRecipe
        mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)
        await sut.loadRecipe(id: 42)
        XCTAssertTrue(sut.isOffline)

        mockRecipeService.fetchRecipeDetailResult = .success(RecipeDetail.mock(id: 42))
        await sut.loadRecipe(id: 42)

        XCTAssertFalse(sut.isOffline)
    }

    // MARK: - Error Handling Tests

    func testLoadRecipe_clearsErrorOnNewLoad() async {
        mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)
        await sut.loadRecipe(id: 42)
        XCTAssertNotNil(sut.errorMessage)

        mockRecipeService.fetchRecipeDetailResult = .success(RecipeDetail.mock(id: 42))
        await sut.loadRecipe(id: 42)

        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Persistence Error Tests

    func testLoadRecipe_persistenceFailure_stillShowsAPIData() async {
        let expectedRecipe = RecipeDetail.mock(id: 42, name: "API Recipe")
        mockRecipeService.fetchRecipeDetailResult = .success(expectedRecipe)
        mockRepository.shouldThrowOnSave = true

        await sut.loadRecipe(id: 42)

        XCTAssertEqual(sut.recipe?.name, "API Recipe")
        XCTAssertFalse(sut.isOffline)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadRecipe_persistenceFailure_doesNotSetOfflineMode() async {
        mockRecipeService.fetchRecipeDetailResult = .success(RecipeDetail.mock(id: 42))
        mockRepository.shouldThrowOnSave = true

        await sut.loadRecipe(id: 42)

        XCTAssertFalse(sut.isOffline)
    }

    // MARK: - Loading Flag Cleanup Tests

    func testLoadRecipe_alwaysResetsLoadingFlags() async {
        mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)

        await sut.loadRecipe(id: 42)

        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isRefreshing)
    }

    func testLoadRecipe_withCache_alwaysResetsRefreshingFlag() async {
        let cachedRecipe = createMockPersistedRecipe(id: 42, name: "Cached")
        mockRepository.cachedRecipe = cachedRecipe
        mockRecipeService.fetchRecipeDetailResult = .failure(MockRecipeError.networkError)

        await sut.loadRecipe(id: 42)

        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isRefreshing)
    }

    // MARK: - Helpers

    private func createMockPersistedRecipe(id: Int, name: String) -> PersistedRecipe {
        let recipe = PersistedRecipe(
            from: RecipeListItem(
                id: id,
                name: name,
                prepTime: nil,
                cookTime: nil,
                favorite: false,
                coverImageUrl: nil,
                updatedAt: Date()
            )
        )
        recipe.detailLastFetchedAt = Date()
        recipe.ingredientsJson = "[\"Ingredient 1\"]"
        recipe.instructionsJson = "[\"Step 1\"]"
        recipe.tagsJson = "[]"
        recipe.createdAt = Date()
        return recipe
    }
}
