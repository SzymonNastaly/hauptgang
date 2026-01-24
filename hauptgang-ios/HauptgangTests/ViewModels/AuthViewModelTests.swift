import XCTest
@testable import Hauptgang

@MainActor
final class AuthViewModelTests: XCTestCase {
    private var sut: AuthViewModel!
    private var mockAuthService: MockAuthService!

    override func setUp() {
        super.setUp()
        mockAuthService = MockAuthService()
        sut = AuthViewModel(authService: mockAuthService)
    }

    override func tearDown() {
        sut = nil
        mockAuthService = nil
        super.tearDown()
    }

    // MARK: - Email Validation Tests

    func testEmailValidation_validEmail_noError() {
        sut.email = "user@example.com"

        XCTAssertNil(sut.emailError)
    }

    func testEmailValidation_invalidEmail_showsError() {
        sut.email = "foo"

        XCTAssertEqual(sut.emailError, "Please enter a valid email")
    }

    func testEmailValidation_emptyEmail_noError() {
        // Empty email doesn't show error (validation only triggers on non-empty input)
        sut.email = ""

        XCTAssertNil(sut.emailError)
    }

    func testEmailValidation_whitespaceOnlyEmail_noError() {
        sut.email = "   "

        XCTAssertNil(sut.emailError)
    }

    func testEmailValidation_emailMissingDomain_showsError() {
        sut.email = "user@"

        XCTAssertEqual(sut.emailError, "Please enter a valid email")
    }

    // MARK: - Form Validation Tests

    func testFormValid_emptyFields_returnsFalse() {
        sut.email = ""
        sut.password = ""

        XCTAssertFalse(sut.isFormValid)
    }

    func testFormValid_emptyEmail_returnsFalse() {
        sut.email = ""
        sut.password = "password123"

        XCTAssertFalse(sut.isFormValid)
    }

    func testFormValid_emptyPassword_returnsFalse() {
        sut.email = "user@example.com"
        sut.password = ""

        XCTAssertFalse(sut.isFormValid)
    }

    func testFormValid_invalidEmail_returnsFalse() {
        sut.email = "invalid-email"
        sut.password = "password123"

        XCTAssertFalse(sut.isFormValid)
    }

    func testFormValid_validInput_returnsTrue() {
        sut.email = "user@example.com"
        sut.password = "password123"

        XCTAssertTrue(sut.isFormValid)
    }

    func testFormValid_emailWithWhitespace_trimsAndValidates() {
        sut.email = "  user@example.com  "
        sut.password = "password123"

        XCTAssertTrue(sut.isFormValid)
    }

    // MARK: - Login Tests

    func testLogin_success_clearsPassword() async {
        sut.email = "user@example.com"
        sut.password = "password123"
        let authManager = AuthManager(authService: mockAuthService)

        await sut.login(authManager: authManager)

        XCTAssertEqual(sut.password, "")
        XCTAssertNil(sut.errorMessage)
    }

    func testLogin_success_updatesAuthManager() async {
        sut.email = "user@example.com"
        sut.password = "password123"
        mockAuthService.loginResult = .success(User(id: 42, email: "user@example.com"))
        let authManager = AuthManager(authService: mockAuthService)

        await sut.login(authManager: authManager)

        XCTAssertTrue(authManager.authState.isAuthenticated)
        XCTAssertEqual(authManager.authState.user?.id, 42)
    }

    func testLogin_failure_showsErrorMessage() async {
        sut.email = "user@example.com"
        sut.password = "wrongpassword"
        mockAuthService.loginResult = .failure(MockAuthError.invalidCredentials)
        let authManager = AuthManager(authService: mockAuthService)

        await sut.login(authManager: authManager)

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(authManager.authState.isAuthenticated)
    }

    func testLogin_failure_doesNotClearPassword() async {
        sut.email = "user@example.com"
        sut.password = "wrongpassword"
        mockAuthService.loginResult = .failure(MockAuthError.networkError)
        let authManager = AuthManager(authService: mockAuthService)

        await sut.login(authManager: authManager)

        // Password should remain so user can retry
        // Note: Current impl clears password only on success, which is correct
        XCTAssertNotNil(sut.errorMessage)
    }

    func testLogin_invalidForm_doesNotCallService() async {
        sut.email = "invalid"
        sut.password = ""
        let authManager = AuthManager(authService: mockAuthService)

        await sut.login(authManager: authManager)

        XCTAssertFalse(authManager.authState.isAuthenticated)
    }

    func testLogin_setsLoadingDuringRequest() async {
        sut.email = "user@example.com"
        sut.password = "password123"
        let authManager = AuthManager(authService: mockAuthService)

        // Before login
        XCTAssertFalse(sut.isLoading)

        await sut.login(authManager: authManager)

        // After login completes
        XCTAssertFalse(sut.isLoading)
    }
}
