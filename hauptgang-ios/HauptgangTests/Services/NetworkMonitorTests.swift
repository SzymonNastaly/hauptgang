@testable import Hauptgang
import Network
import XCTest

@MainActor
final class NetworkMonitorTests: XCTestCase {
    private var sut: NetworkMonitor!
    private var pathMonitor: MockPathMonitor!
    private var sessionConfiguration: URLSessionConfiguration!
    private let healthCheckURL = URL(string: "https://example.com/up")!
    private let recoveryIntervalNanoseconds: UInt64 = 20_000_000

    override func setUp() async throws {
        try await super.setUp()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NetworkMonitorMockURLProtocol.self]

        self.sessionConfiguration = configuration
        self.pathMonitor = MockPathMonitor(initialStatus: .unsatisfied)
        self.sut = NetworkMonitor(
            pathMonitor: self.pathMonitor,
            sessionFactory: { URLSession(configuration: configuration) },
            healthCheckURL: self.healthCheckURL,
            recoveryIntervalNanoseconds: self.recoveryIntervalNanoseconds
        )
    }

    override func tearDown() async throws {
        self.sut?.shutdown()
        NetworkMonitorMockURLProtocol.reset()
        self.sut = nil
        self.pathMonitor = nil
        self.sessionConfiguration = nil
        try await super.tearDown()
    }

    func testRefreshStatus_whenHealthCheckSucceeds_clearsOffline() async {
        self.pathMonitor.currentStatus = .satisfied
        NetworkMonitorMockURLProtocol.requestHandler = { [healthCheckURL] request in
            XCTAssertEqual(request.url, healthCheckURL)
            XCTAssertEqual(request.httpMethod, "GET")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await self.sut.refreshStatus()

        XCTAssertFalse(self.sut.isOffline)
    }

    func testRefreshStatus_whenPathIsUnsatisfiedButHealthCheckSucceeds_clearsOffline() async {
        NetworkMonitorMockURLProtocol.requestHandler = { [healthCheckURL] request in
            XCTAssertEqual(request.url, healthCheckURL)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await self.sut.refreshStatus()

        XCTAssertFalse(self.sut.isOffline)
    }

    func testPathRestored_whenHealthCheckSucceeds_clearsOffline() async throws {
        NetworkMonitorMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        self.pathMonitor.send(.satisfied)
        try await self.waitUntil { !self.sut.isOffline }

        XCTAssertFalse(self.sut.isOffline)
    }

    func testPathLost_whenRecoveryProbeEventuallySucceedsWithoutPathRestore_clearsOffline() async throws {
        self.pathMonitor.currentStatus = .satisfied
        NetworkMonitorMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await self.sut.refreshStatus()
        XCTAssertFalse(self.sut.isOffline)

        NetworkMonitorMockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        self.pathMonitor.send(.unsatisfied)
        try await self.waitUntil { self.sut.isOffline }

        try await Task.sleep(nanoseconds: self.recoveryIntervalNanoseconds * 2)

        NetworkMonitorMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        try await self.waitUntil(timeoutNanoseconds: 2_000_000_000) { !self.sut.isOffline }

        XCTAssertFalse(self.sut.isOffline)
    }

    func testRefreshStatus_whenHealthCheckFails_keepsOffline() async {
        self.pathMonitor.currentStatus = .satisfied
        NetworkMonitorMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await self.sut.refreshStatus()

        XCTAssertTrue(self.sut.isOffline)
    }

    func testRefreshStatus_usesFreshSessionForLaterProbeRecovery() async {
        let failingConfiguration = URLSessionConfiguration.ephemeral
        failingConfiguration.protocolClasses = [AlwaysFailingNetworkMonitorURLProtocol.self]
        let failingSession = URLSession(configuration: failingConfiguration)

        let succeedingConfiguration = URLSessionConfiguration.ephemeral
        succeedingConfiguration.protocolClasses = [AlwaysSucceedingNetworkMonitorURLProtocol.self]
        let succeedingSession = URLSession(configuration: succeedingConfiguration)

        let sessionFactory = MutableSessionFactory(session: failingSession)
        let pathMonitor = MockPathMonitor(initialStatus: .unsatisfied)
        let monitor = NetworkMonitor(
            pathMonitor: pathMonitor,
            sessionFactory: { sessionFactory.session },
            healthCheckURL: self.healthCheckURL,
            recoveryIntervalNanoseconds: self.recoveryIntervalNanoseconds
        )
        defer { monitor.shutdown() }

        await monitor.refreshStatus()
        XCTAssertTrue(monitor.isOffline)

        sessionFactory.session = succeedingSession

        await monitor.refreshStatus()
        XCTAssertFalse(monitor.isOffline)
    }

    func testDisabledAutomaticMonitoring_doesNotStartMonitorOrProbe() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NetworkMonitorMockURLProtocol.self]

        let session = URLSession(configuration: configuration)
        let pathMonitor = MockPathMonitor(initialStatus: .satisfied)
        let monitor = NetworkMonitor(
            pathMonitor: pathMonitor,
            session: session,
            healthCheckURL: self.healthCheckURL,
            recoveryIntervalNanoseconds: self.recoveryIntervalNanoseconds,
            automaticMonitoringEnabled: false
        )

        await monitor.refreshStatus()
        monitor.appDidBecomeActive()

        XCTAssertEqual(pathMonitor.startCallCount, 0)
        XCTAssertFalse(monitor.isOffline)
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTFail("Condition not met before timeout")
    }
}

private final class MutableSessionFactory {
    var session: URLSession

    init(session: URLSession) {
        self.session = session
    }
}

private final class MockPathMonitor: NetworkPathMonitoring {
    var currentStatus: NWPath.Status
    var pathUpdateHandler: (@Sendable (NWPath.Status) -> Void)?
    private(set) var startCallCount = 0
    private(set) var cancelCallCount = 0

    init(initialStatus: NWPath.Status) {
        self.currentStatus = initialStatus
    }

    func start(queue _: DispatchQueue) {
        self.startCallCount += 1
    }

    func cancel() {
        self.cancelCallCount += 1
    }

    func send(_ status: NWPath.Status) {
        self.currentStatus = status
        self.pathUpdateHandler?(status)
    }
}

private final class AlwaysFailingNetworkMonitorURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        self.client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

private final class AlwaysSucceedingNetworkMonitorURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: self.request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        self.client?.urlProtocol(self, didLoad: Data())
        self.client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class NetworkMonitorMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        self.requestHandler = nil
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            self.client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            return
        }

        do {
            let (response, data) = try handler(self.request)
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        } catch {
            self.client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
