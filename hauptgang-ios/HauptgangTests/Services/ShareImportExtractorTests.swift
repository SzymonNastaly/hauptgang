@testable import Hauptgang
import UniformTypeIdentifiers
import XCTest

final class ShareImportExtractorTests: XCTestCase {
    func testPropertyList_withValidJSResults_returnsSuccessPageContent() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/recipe"))
        let provider = FakeShareItemProvider(
            registeredTypeIdentifiers: [UTType.propertyList.identifier],
            loadItemResults: [
                UTType.propertyList.identifier: .success(self.makePropertyList(jsValues: [
                    "url": url.absoluteString,
                    "jsonLd": ["{\"@type\":\"Recipe\"}"],
                    "metaTags": ["og:title": "Example Recipe"],
                    "coverImageCandidates": ["https://example.com/cover.jpg"],
                    "html": "<body><article>Recipe</article></body>"
                ]))
            ]
        )

        let result = await ShareImportExtractor.extractWebPageData(from: [provider])
        guard case let .success(pageContent) = result else {
            return XCTFail("Expected .success but got \(result)")
        }

        XCTAssertEqual(pageContent.url, url)
        XCTAssertEqual(pageContent.jsonLd.count, 1)
        XCTAssertEqual(pageContent.metaTags["og:title"], "Example Recipe")
        XCTAssertEqual(pageContent.coverImageCandidates, ["https://example.com/cover.jpg"])
        XCTAssertEqual(pageContent.html, "<body><article>Recipe</article></body>")
    }

    func testPropertyList_withEmptyJSResults_butURLInside_returnsUrlOnly() async throws {
        let fallbackURL = try XCTUnwrap(URL(string: "https://example.com/from-plist"))
        let provider = FakeShareItemProvider(
            registeredTypeIdentifiers: [UTType.propertyList.identifier],
            loadItemResults: [
                UTType.propertyList.identifier: .success([
                    NSExtensionJavaScriptPreprocessingResultsKey: [:] as NSDictionary,
                    "URL": fallbackURL.absoluteString
                ] as NSDictionary)
            ]
        )

        let result = await ShareImportExtractor.extractWebPageData(from: [provider])
        guard case let .urlOnly(url) = result else {
            return XCTFail("Expected .urlOnly but got \(result)")
        }

        XCTAssertEqual(url, fallbackURL)
    }

    func testPropertyList_noJS_noURL_thenURLAttachment_returnsUrl() async throws {
        let attachmentURL = try XCTUnwrap(URL(string: "https://example.com/url-attachment"))

        let propertyListProvider = FakeShareItemProvider(
            registeredTypeIdentifiers: [UTType.propertyList.identifier],
            loadItemResults: [
                UTType.propertyList.identifier: .success([
                    NSExtensionJavaScriptPreprocessingResultsKey: ["notAURL": "value"] as NSDictionary
                ] as NSDictionary)
            ]
        )
        let urlProvider = FakeShareItemProvider(
            registeredTypeIdentifiers: [UTType.url.identifier],
            loadItemResults: [UTType.url.identifier: .success(attachmentURL as NSURL)]
        )

        let webResult = await ShareImportExtractor.extractWebPageData(from: [propertyListProvider, urlProvider])
        if case .none = webResult {
            // expected
        } else {
            XCTFail("Expected .none from web-page extraction but got \(webResult)")
        }

        let extractedURL = await ShareImportExtractor.extractURL(from: [propertyListProvider, urlProvider])
        XCTAssertEqual(extractedURL, attachmentURL)
    }

    func testPlainTextURL_only_returnsURL() async throws {
        let textURL = try XCTUnwrap(URL(string: "https://example.com/plain-text"))
        let provider = FakeShareItemProvider(
            registeredTypeIdentifiers: [UTType.plainText.identifier],
            loadItemResults: [UTType.plainText.identifier: .success(textURL.absoluteString as NSString)]
        )

        let result = await ShareImportExtractor.extractURL(from: [provider])
        XCTAssertEqual(result, textURL)
    }

    func testNoURL_thenImageAttachment_returnsImageURL() async throws {
        let sourceImageURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try Data([0x01, 0x02, 0x03]).write(to: sourceImageURL)

        let provider = FakeShareItemProvider(
            registeredTypeIdentifiers: [UTType.image.identifier],
            loadFileRepresentationResults: [UTType.image.identifier: .success(sourceImageURL)]
        )

        let extractedURL = await ShareImportExtractor.extractImageFileURL(from: [provider])
        XCTAssertNotNil(extractedURL)
        if let extractedURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedURL.path))
            try? FileManager.default.removeItem(at: extractedURL)
        }
        try? FileManager.default.removeItem(at: sourceImageURL)
    }

    func testNoUsableAttachments_returnsNoneOrNil() async {
        let provider = FakeShareItemProvider(
            registeredTypeIdentifiers: ["com.example.unknown"]
        )

        let webResult = await ShareImportExtractor.extractWebPageData(from: [provider])
        if case .none = webResult {
            // expected
        } else {
            XCTFail("Expected .none but got \(webResult)")
        }
        let extractedURL = await ShareImportExtractor.extractURL(from: [provider])
        XCTAssertNil(extractedURL)
        let extractedImageURL = await ShareImportExtractor.extractImageFileURL(from: [provider])
        XCTAssertNil(extractedImageURL)
    }

    func testPropertyList_withError_doesNotCrash_andFallsBack() async throws {
        struct TestError: Error {}

        let propertyListProvider = FakeShareItemProvider(
            registeredTypeIdentifiers: [UTType.propertyList.identifier],
            loadItemResults: [UTType.propertyList.identifier: .failure(TestError())]
        )
        let plainTextURL = try XCTUnwrap(URL(string: "https://example.com/fallback-after-error"))
        let plainTextProvider = FakeShareItemProvider(
            registeredTypeIdentifiers: [UTType.plainText.identifier],
            loadItemResults: [UTType.plainText.identifier: .success(plainTextURL.absoluteString as NSString)]
        )

        let webResult = await ShareImportExtractor.extractWebPageData(from: [propertyListProvider, plainTextProvider])
        if case .none = webResult {
            // expected
        } else {
            XCTFail("Expected .none after property-list error but got \(webResult)")
        }

        let url = await ShareImportExtractor.extractURL(from: [propertyListProvider, plainTextProvider])
        XCTAssertEqual(url, plainTextURL)
    }

    func testPropertyList_urlFallbackSearch_recoversNestedURLWithinDepthLimit() async throws {
        let fallbackURL = try XCTUnwrap(URL(string: "https://example.com/deep-url"))
        let nested = self.makeDeepNestedDictionary(depth: 12, leafKey: "url", leafValue: fallbackURL.absoluteString)
        let provider = FakeShareItemProvider(
            registeredTypeIdentifiers: [UTType.propertyList.identifier],
            loadItemResults: [
                UTType.propertyList.identifier: .success([
                    NSExtensionJavaScriptPreprocessingResultsKey: nested
                ] as NSDictionary)
            ]
        )

        let result = await ShareImportExtractor.extractWebPageData(from: [provider])
        guard case let .urlOnly(url) = result else {
            return XCTFail("Expected .urlOnly but got \(result)")
        }

        XCTAssertEqual(url, fallbackURL)
    }

    func testPropertyList_urlFallbackSearch_stopsBeyondDepthLimit() async throws {
        let fallbackURL = try XCTUnwrap(URL(string: "https://example.com/too-deep"))
        let nested = self.makeDeepNestedDictionary(depth: 25, leafKey: "url", leafValue: fallbackURL.absoluteString)
        let provider = FakeShareItemProvider(
            registeredTypeIdentifiers: [UTType.propertyList.identifier],
            loadItemResults: [
                UTType.propertyList.identifier: .success([
                    NSExtensionJavaScriptPreprocessingResultsKey: nested
                ] as NSDictionary)
            ]
        )

        let result = await ShareImportExtractor.extractWebPageData(from: [provider])
        guard case .none = result else {
            return XCTFail("Expected .none but got \(result)")
        }
    }

    private func makePropertyList(jsValues: [String: Any]) -> NSDictionary {
        [NSExtensionJavaScriptPreprocessingResultsKey: jsValues] as NSDictionary
    }

    private func makeDeepNestedDictionary(depth: Int, leafKey: String, leafValue: String) -> NSDictionary {
        var current: NSDictionary = [leafKey: leafValue]
        for _ in 0 ..< depth {
            current = ["child": current]
        }
        return current
    }
}

private final class FakeShareItemProvider: ShareItemProviding {
    let registeredTypeIdentifiers: [String]
    private let loadItemResults: [String: Result<NSSecureCoding?, Error>]
    private let loadFileRepresentationResults: [String: Result<URL?, Error>]

    init(
        registeredTypeIdentifiers: [String],
        loadItemResults: [String: Result<NSSecureCoding?, Error>] = [:],
        loadFileRepresentationResults: [String: Result<URL?, Error>] = [:]
    ) {
        self.registeredTypeIdentifiers = registeredTypeIdentifiers
        self.loadItemResults = loadItemResults
        self.loadFileRepresentationResults = loadFileRepresentationResults
    }

    func hasItemConformingToTypeIdentifier(_ typeIdentifier: String) -> Bool {
        self.registeredTypeIdentifiers.contains(typeIdentifier)
    }

    func loadItem(
        forTypeIdentifier typeIdentifier: String,
        options _: [AnyHashable: Any]?
    ) async throws -> NSSecureCoding? {
        guard let result = loadItemResults[typeIdentifier] else {
            return nil
        }
        return try result.get()
    }

    func loadFileRepresentation(forTypeIdentifier typeIdentifier: String) async throws -> URL? {
        guard let result = loadFileRepresentationResults[typeIdentifier] else {
            return nil
        }
        return try result.get()
    }
}
