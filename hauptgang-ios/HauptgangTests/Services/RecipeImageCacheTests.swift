@testable import Hauptgang
import Foundation
import XCTest

final class RecipeImageCacheTests: XCTestCase {
    private var session: URLSession!
    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RecipeImageCacheMockURLProtocol.self]
        session = URLSession(configuration: config)

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecipeImageCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        RecipeImageCacheMockURLProtocol.reset()
    }

    override func tearDown() async throws {
        RecipeImageCacheMockURLProtocol.reset()
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        session = nil
        tempDirectory = nil
        try await super.tearDown()
    }

    func testImage_secondRequestUsesCacheWithoutSecondNetworkHit() async throws {
        let url = URL(string: "https://example.com/recipe-thumbnail.webp")!
        let imageData = try XCTUnwrap(Self.sampleImageData)
        RecipeImageCacheMockURLProtocol.requestCount = 0
        RecipeImageCacheMockURLProtocol.requestHandler = { request in
            RecipeImageCacheMockURLProtocol.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData)
        }

        let cache = RecipeImageCache(
            session: session,
            cacheDirectory: tempDirectory,
            maxAge: 60,
            maxDiskSizeBytes: 10 * 1024 * 1024
        )

        _ = try await cache.image(for: url)
        _ = try await cache.image(for: url)

        XCTAssertEqual(RecipeImageCacheMockURLProtocol.requestCount, 1)
    }

    func testImage_expiredDiskEntryRefetches() async throws {
        let url = URL(string: "https://example.com/recipe-thumbnail.webp")!
        let imageData = try XCTUnwrap(Self.sampleImageData)
        RecipeImageCacheMockURLProtocol.requestCount = 0
        RecipeImageCacheMockURLProtocol.requestHandler = { request in
            RecipeImageCacheMockURLProtocol.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData)
        }

        let cacheDirectory = try XCTUnwrap(tempDirectory)
        let firstCache = RecipeImageCache(
            session: session,
            cacheDirectory: cacheDirectory,
            maxAge: 0.05,
            maxDiskSizeBytes: 10 * 1024 * 1024
        )
        _ = try await firstCache.image(for: url)

        try await Task.sleep(for: .milliseconds(120))

        let secondCache = RecipeImageCache(
            session: session,
            cacheDirectory: cacheDirectory,
            maxAge: 0.05,
            maxDiskSizeBytes: 10 * 1024 * 1024
        )
        _ = try await secondCache.image(for: url)

        XCTAssertEqual(RecipeImageCacheMockURLProtocol.requestCount, 2)
    }

    func testImage_concurrentRequestsUseSingleFlightDownload() async throws {
        let url = URL(string: "https://example.com/recipe-thumbnail.webp")!
        let imageData = try XCTUnwrap(Self.sampleImageData)
        RecipeImageCacheMockURLProtocol.requestCount = 0
        RecipeImageCacheMockURLProtocol.requestHandler = { request in
            RecipeImageCacheMockURLProtocol.requestCount += 1
            Thread.sleep(forTimeInterval: 0.15)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData)
        }

        let cache = RecipeImageCache(
            session: session,
            cacheDirectory: tempDirectory,
            maxAge: 60,
            maxDiskSizeBytes: 10 * 1024 * 1024
        )

        async let first = cache.image(for: url)
        async let second = cache.image(for: url)
        _ = try await (first, second)

        XCTAssertEqual(RecipeImageCacheMockURLProtocol.requestCount, 1)
    }

    private static let sampleImageData = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="
    )
}

private final class RecipeImageCacheMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0

    static func reset() {
        requestHandler = nil
        requestCount = 0
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = Self.requestHandler else {
                fatalError("No handler set for RecipeImageCacheMockURLProtocol")
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
