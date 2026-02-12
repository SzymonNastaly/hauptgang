@testable import Hauptgang
import SwiftData
import XCTest

/// Integration tests that require a running Rails server at localhost:3000
/// Run with: `bin/ios-test` (after starting Rails server with `bin/dev`)
///
/// These tests make real API calls and verify the full authentication and
/// data fetching flow works correctly with the backend.
@MainActor
final class APIIntegrationTests: XCTestCase {
    private let testEmail = "test@example.com"
    private let testPassword = "password123"

    // MARK: - Setup/Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Clear any existing auth state to ensure clean test environment
        await KeychainService.shared.clearAll()

        // Check if server is reachable, skip tests if not
        try await self.checkServerReachable()
    }

    override func tearDown() async throws {
        // Clean up auth state after each test
        await KeychainService.shared.clearAll()
        try await super.tearDown()
    }

    // MARK: - Server Reachability

    /// Checks if the Rails server is running and skips tests if not.
    /// This allows running `bin/ios-test` without failures when the server is down.
    private func checkServerReachable() async throws {
        let url = Constants.API.baseURL
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 499).contains(httpResponse.statusCode)
            else {
                throw XCTSkip("Rails server not reachable at \(url)")
            }
        } catch is XCTSkip {
            throw XCTSkip("Rails server not reachable at \(url)")
        } catch {
            throw XCTSkip("Rails server not reachable: \(error.localizedDescription)")
        }
    }

    // MARK: - Login Tests

    func testLogin_withValidCredentials_succeeds() async throws {
        // When: logging in with valid credentials
        let user = try await AuthService.shared.login(
            email: self.testEmail,
            password: self.testPassword
        )

        // Then: user is returned with correct email
        XCTAssertEqual(user.email, self.testEmail)

        // And: token is stored in keychain
        let storedToken = await KeychainService.shared.getToken()
        XCTAssertNotNil(storedToken, "Token should be stored after login")

        // And: user is stored in keychain
        let storedUser = await KeychainService.shared.getUser()
        XCTAssertNotNil(storedUser, "User should be stored after login")
        XCTAssertEqual(storedUser?.email, self.testEmail)
    }

    func testLogin_withInvalidCredentials_throwsError() async throws {
        // When: logging in with wrong password
        do {
            _ = try await AuthService.shared.login(
                email: self.testEmail,
                password: "wrong_password"
            )
            XCTFail("Login should have thrown an error")
        } catch let error as APIError {
            // Then: invalidCredentials error is thrown
            XCTAssertEqual(error, .invalidCredentials, "Expected invalidCredentials error")
        }

        // And: no token should be stored
        let storedToken = await KeychainService.shared.getToken()
        XCTAssertNil(storedToken, "No token should be stored after failed login")
    }

    // MARK: - Recipe Tests

    func testFetchRecipes_afterLogin_returnsRecipes() async throws {
        // Given: user is logged in
        _ = try await AuthService.shared.login(
            email: self.testEmail,
            password: self.testPassword
        )

        // When: fetching recipes
        let recipes = try await RecipeService.shared.fetchRecipes()

        // Then: recipes array is returned (may be empty, but shouldn't crash)
        XCTAssertGreaterThanOrEqual(recipes.count, 0, "Recipes should be an array")

        // And: if recipes exist, they have valid structure
        for recipe in recipes {
            XCTAssertGreaterThan(recipe.id, 0, "Recipe should have valid ID")
            XCTAssertFalse(recipe.name.isEmpty, "Recipe should have a name")
            // updatedAt is a Date - just verify it exists by accessing it
            _ = recipe.updatedAt
        }
    }

    func testFetchRecipes_withoutLogin_throwsUnauthorized() async throws {
        // Given: no user is logged in (keychain cleared in setUp)

        // When: attempting to fetch recipes without authentication
        do {
            _ = try await RecipeService.shared.fetchRecipes()
            XCTFail("Fetch should have thrown an error")
        } catch let error as APIError {
            // Then: unauthorized error is thrown
            XCTAssertEqual(error, .unauthorized, "Expected unauthorized error")
        }
    }

    // MARK: - Logout Tests

    func testLogout_clearsAuthState() async throws {
        // Given: user is logged in
        _ = try await AuthService.shared.login(
            email: self.testEmail,
            password: self.testPassword
        )

        // Verify we're logged in
        let beforeLogout = await AuthService.shared.isAuthenticated()
        XCTAssertTrue(beforeLogout, "Should be authenticated before logout")

        // When: logging out
        await AuthService.shared.logout()

        // Then: getCurrentUser returns nil
        let currentUser = await AuthService.shared.getCurrentUser()
        XCTAssertNil(currentUser, "getCurrentUser should return nil after logout")

        // And: isAuthenticated returns false
        let isAuthenticated = await AuthService.shared.isAuthenticated()
        XCTAssertFalse(isAuthenticated, "Should not be authenticated after logout")

        // And: keychain is cleared
        let token = await KeychainService.shared.getToken()
        XCTAssertNil(token, "Token should be cleared from keychain")
    }

    // MARK: - SwiftData Persistence Tests

    func testRecipePersistence_savesAndLoadsRecipes() async throws {
        // Given: user is logged in and we have recipes from API
        _ = try await AuthService.shared.login(
            email: self.testEmail,
            password: self.testPassword
        )

        let apiRecipes = try await RecipeService.shared.fetchRecipes()

        // Skip test if no recipes returned from API
        guard !apiRecipes.isEmpty else {
            throw XCTSkip("No recipes returned from API - cannot test persistence")
        }

        // When: saving recipes to SwiftData
        let container = try createTestModelContainer()
        let context = ModelContext(container)
        let repository = RecipeRepository()
        repository.configure(modelContext: context)

        try repository.saveRecipes(apiRecipes)

        // Then: recipes can be loaded from SwiftData
        let loadedRecipes = try repository.getAllRecipes()

        // And: count matches what was saved
        XCTAssertEqual(loadedRecipes.count, apiRecipes.count, "Should load same number of recipes")

        // And: recipe data matches
        for apiRecipe in apiRecipes {
            let persisted = loadedRecipes.first { $0.id == apiRecipe.id }
            XCTAssertNotNil(persisted, "Recipe \(apiRecipe.id) should be persisted")
            XCTAssertEqual(persisted?.name, apiRecipe.name, "Recipe name should match")
            XCTAssertEqual(persisted?.favorite, apiRecipe.favorite, "Recipe favorite should match")
        }
    }

    func testSearchIndex_afterLogin_indexesAndFindsRecipe() async throws {
        let user = try await AuthService.shared.login(
            email: self.testEmail,
            password: self.testPassword
        )

        let searchIndex = RecipeSearchIndex.shared
        await searchIndex.configure(userId: user.id)
        await searchIndex.reset()
        await searchIndex.configure(userId: user.id)
        defer { Task { await searchIndex.reset() } }

        guard await searchIndex.isAvailable() else {
            throw XCTSkip("FTS5 not available on this device")
        }

        let list = try await RecipeService.shared.fetchRecipes()
        guard let listItem = list.first else {
            throw XCTSkip("No recipes returned from API - cannot test search")
        }

        let recipe = try await RecipeService.shared.fetchRecipeDetail(id: listItem.id)

        guard let token = self.searchToken(from: recipe.name) else {
            throw XCTSkip("Recipe name not searchable: \(recipe.name)")
        }

        let detailInput = SearchIndexDetailInput(
            id: recipe.id,
            name: recipe.name,
            ingredients: recipe.ingredients,
            instructions: recipe.instructions,
            updatedAt: recipe.updatedAt
        )

        await searchIndex.rebuildIndex(with: [detailInput])

        let results = await searchIndex.search("\(token)*", limit: 10)
        XCTAssertTrue(results.contains(recipe.id), "Search should return the indexed recipe")
    }

    // MARK: - Full Flow Tests

    func testFullAuthFlow_loginFetchLogout() async throws {
        // Step 1: Login
        let user = try await AuthService.shared.login(
            email: self.testEmail,
            password: self.testPassword
        )
        XCTAssertEqual(user.email, self.testEmail)

        var isAuth = await AuthService.shared.isAuthenticated()
        XCTAssertTrue(isAuth, "Should be authenticated after login")

        // Step 2: Fetch recipes (should work while authenticated)
        let recipes = try await RecipeService.shared.fetchRecipes()
        // Just verify we got a response - count may be 0
        XCTAssertGreaterThanOrEqual(recipes.count, 0)

        // Step 3: Logout
        await AuthService.shared.logout()

        isAuth = await AuthService.shared.isAuthenticated()
        XCTAssertFalse(isAuth, "Should not be authenticated after logout")

        // Step 4: Fetch recipes again - should fail
        do {
            _ = try await RecipeService.shared.fetchRecipes()
            XCTFail("Fetch should fail after logout")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized, "Should get unauthorized after logout")
        }
    }

    // MARK: - Helpers

    /// Creates an in-memory SwiftData container for testing persistence
    /// without affecting the app's actual database.
    private func createTestModelContainer() throws -> ModelContainer {
        let schema = Schema([PersistedRecipe.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func searchToken(from name: String) -> String? {
        let components = name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return components.first?.lowercased()
    }
}

// MARK: - APIError Equatable

extension APIError: @retroactive Equatable {
    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.invalidCredentials, .invalidCredentials),
             (.unknown, .unknown):
            true
        case let (.serverError(lhsCode), .serverError(rhsCode)):
            lhsCode == rhsCode
        case (.networkError, .networkError),
             (.decodingError, .decodingError):
            // These contain Error which isn't Equatable, so just check type
            true
        default:
            false
        }
    }
}
