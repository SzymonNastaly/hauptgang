import XCTest
@testable import Hauptgang

final class ShareImportExtractorTests: XCTestCase {
    // MARK: - urlFromPlainText Tests

    func testUrlFromPlainText_validHttpsUrl_returnsUrl() {
        let result = ShareImportExtractor.urlFromPlainText("https://example.com/recipe")
        XCTAssertEqual(result?.absoluteString, "https://example.com/recipe")
    }

    func testUrlFromPlainText_validHttpUrl_returnsUrl() {
        let result = ShareImportExtractor.urlFromPlainText("http://example.com")
        XCTAssertEqual(result?.absoluteString, "http://example.com")
    }

    func testUrlFromPlainText_withLeadingWhitespace_trimsAndReturnsUrl() {
        let result = ShareImportExtractor.urlFromPlainText("   https://example.com")
        XCTAssertEqual(result?.absoluteString, "https://example.com")
    }

    func testUrlFromPlainText_withTrailingWhitespace_trimsAndReturnsUrl() {
        let result = ShareImportExtractor.urlFromPlainText("https://example.com   ")
        XCTAssertEqual(result?.absoluteString, "https://example.com")
    }

    func testUrlFromPlainText_withSurroundingWhitespaceAndNewlines_trimsAndReturnsUrl() {
        let result = ShareImportExtractor.urlFromPlainText("\n  https://example.com  \n")
        XCTAssertEqual(result?.absoluteString, "https://example.com")
    }

    func testUrlFromPlainText_withoutScheme_returnsNil() {
        let result = ShareImportExtractor.urlFromPlainText("example.com/recipe")
        XCTAssertNil(result)
    }

    func testUrlFromPlainText_emptyString_returnsNil() {
        let result = ShareImportExtractor.urlFromPlainText("")
        XCTAssertNil(result)
    }

    func testUrlFromPlainText_whitespaceOnly_returnsNil() {
        let result = ShareImportExtractor.urlFromPlainText("   ")
        XCTAssertNil(result)
    }

    func testUrlFromPlainText_plainText_returnsNil() {
        let result = ShareImportExtractor.urlFromPlainText("This is just some text about a recipe")
        XCTAssertNil(result)
    }

    func testUrlFromPlainText_invalidUrl_returnsNil() {
        let result = ShareImportExtractor.urlFromPlainText("not a valid url at all")
        XCTAssertNil(result)
    }

    func testUrlFromPlainText_fileScheme_returnsUrl() {
        let result = ShareImportExtractor.urlFromPlainText("file:///path/to/file")
        XCTAssertEqual(result?.scheme, "file")
    }

    func testUrlFromPlainText_customScheme_returnsUrl() {
        let result = ShareImportExtractor.urlFromPlainText("hauptgang://recipe/123")
        XCTAssertEqual(result?.scheme, "hauptgang")
    }

    func testUrlFromPlainText_urlWithQueryParams_returnsUrl() {
        let result = ShareImportExtractor.urlFromPlainText("https://example.com/recipe?id=123&name=test")
        XCTAssertEqual(result?.absoluteString, "https://example.com/recipe?id=123&name=test")
    }

    func testUrlFromPlainText_urlWithFragment_returnsUrl() {
        let result = ShareImportExtractor.urlFromPlainText("https://example.com/recipe#ingredients")
        XCTAssertEqual(result?.absoluteString, "https://example.com/recipe#ingredients")
    }

    // MARK: - extractURL with NSItemProvider Tests
    // Note: NSItemProvider-based async tests are unreliable in XCTest because
    // loadItem returns serialized data differently than in the actual share extension context.
    // The pure urlFromPlainText tests above cover the core parsing logic.

    func testExtractURL_withEmptyAttachments_returnsNil() async {
        let result = await ShareImportExtractor.extractURL(from: [])
        XCTAssertNil(result)
    }
}
