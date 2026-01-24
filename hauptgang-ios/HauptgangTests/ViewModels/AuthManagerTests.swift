import XCTest
@testable import Hauptgang

@MainActor
final class AuthManagerTests: XCTestCase {
    private var sut: AuthManager!
    private var mockAuthService: MockAuthService!

    override func setUp() {
        super.setUp()
        mockAuthService = MockAuthService()
        sut = AuthManager(authService: mockAuthService)
    }

    override func tearDown() {
        sut = nil
        mockAuthService = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_isUnknown() {
        XCTAssertEqual(sut.authState, .unknown)
    }

    // MARK: - Check Auth Status Tests

    func testCheckAuthStatus_withUser_becomesAuthenticated() {
        let user = User(id: 1, email: "user@example.com")
        mockAuthService.currentUser = user

        sut.checkAuthStatus()

        XCTAssertEqual(sut.authState, .authenticated(user))
        XCTAssertTrue(sut.authState.isAuthenticated)
        XCTAssertEqual(sut.authState.user, user)
    }

    func testCheckAuthStatus_noUser_becomesUnauthenticated() {
        mockAuthService.currentUser = nil

        sut.checkAuthStatus()

        XCTAssertEqual(sut.authState, .unauthenticated)
        XCTAssertFalse(sut.authState.isAuthenticated)
        XCTAssertNil(sut.authState.user)
    }

    // MARK: - Sign In Tests

    func testSignIn_updatesStateToAuthenticated() {
        let user = User(id: 42, email: "newuser@example.com")

        sut.signIn(user: user)

        XCTAssertEqual(sut.authState, .authenticated(user))
        XCTAssertTrue(sut.authState.isAuthenticated)
        XCTAssertEqual(sut.authState.user?.id, 42)
        XCTAssertEqual(sut.authState.user?.email, "newuser@example.com")
    }

    func testSignIn_fromUnauthenticated_becomesAuthenticated() {
        sut.checkAuthStatus() // Sets to .unauthenticated
        XCTAssertEqual(sut.authState, .unauthenticated)

        let user = User(id: 1, email: "user@example.com")
        sut.signIn(user: user)

        XCTAssertEqual(sut.authState, .authenticated(user))
    }

    // MARK: - Sign Out Tests

    func testSignOut_clearsStateToUnauthenticated() async {
        let user = User(id: 1, email: "user@example.com")
        sut.signIn(user: user)
        XCTAssertTrue(sut.authState.isAuthenticated)

        await sut.signOut()

        XCTAssertEqual(sut.authState, .unauthenticated)
        XCTAssertFalse(sut.authState.isAuthenticated)
        XCTAssertNil(sut.authState.user)
    }

    func testSignOut_callsLogoutOnService() async {
        sut.signIn(user: User(id: 1, email: "user@example.com"))

        await sut.signOut()

        XCTAssertTrue(mockAuthService.logoutCalled)
    }

    // MARK: - AuthState Equatable Tests

    func testAuthState_unknownEquality() {
        let state1 = AuthManager.AuthState.unknown
        let state2 = AuthManager.AuthState.unknown

        XCTAssertEqual(state1, state2)
    }

    func testAuthState_unauthenticatedEquality() {
        let state1 = AuthManager.AuthState.unauthenticated
        let state2 = AuthManager.AuthState.unauthenticated

        XCTAssertEqual(state1, state2)
    }

    func testAuthState_authenticatedEquality_sameUser() {
        let user = User(id: 1, email: "user@example.com")
        let state1 = AuthManager.AuthState.authenticated(user)
        let state2 = AuthManager.AuthState.authenticated(user)

        XCTAssertEqual(state1, state2)
    }

    func testAuthState_authenticatedEquality_differentUsers() {
        let user1 = User(id: 1, email: "user1@example.com")
        let user2 = User(id: 2, email: "user2@example.com")
        let state1 = AuthManager.AuthState.authenticated(user1)
        let state2 = AuthManager.AuthState.authenticated(user2)

        XCTAssertNotEqual(state1, state2)
    }

    func testAuthState_differentStatesNotEqual() {
        let user = User(id: 1, email: "user@example.com")

        XCTAssertNotEqual(AuthManager.AuthState.unknown, AuthManager.AuthState.unauthenticated)
        XCTAssertNotEqual(AuthManager.AuthState.unknown, AuthManager.AuthState.authenticated(user))
        XCTAssertNotEqual(AuthManager.AuthState.unauthenticated, AuthManager.AuthState.authenticated(user))
    }
}
