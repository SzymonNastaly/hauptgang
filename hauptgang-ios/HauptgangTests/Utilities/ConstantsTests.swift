@testable import Hauptgang
import XCTest

final class ConstantsTests: XCTestCase {
    // MARK: - resolveURL Tests

    func testResolveURL_withNil_returnsNil() {
        XCTAssertNil(Constants.API.resolveURL(nil))
    }

    func testResolveURL_withEmptyString_returnsNil() {
        XCTAssertNil(Constants.API.resolveURL(""))
    }

    func testResolveURL_withRelativePath_resolvesAgainstHost() throws {
        let result = Constants.API.resolveURL("/rails/active_storage/blobs/123")

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.absoluteString.contains("127.0.0.1:3000")))
        XCTAssertTrue(try XCTUnwrap(result?.absoluteString.contains("/rails/active_storage/blobs/123")))
    }

    func testResolveURL_withAbsoluteHttpUrl_returnsAsIs() {
        let absoluteUrl = "http://example.com/image.jpg"
        let result = Constants.API.resolveURL(absoluteUrl)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, absoluteUrl)
    }

    func testResolveURL_withAbsoluteHttpsUrl_returnsAsIs() {
        let absoluteUrl = "https://example.com/image.jpg"
        let result = Constants.API.resolveURL(absoluteUrl)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, absoluteUrl)
    }
}
