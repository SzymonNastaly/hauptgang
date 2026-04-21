import Foundation
import Network
import Observation
import os

@MainActor
protocol NetworkStatusProviding: AnyObject {
    var isOffline: Bool { get }
}

protocol NetworkPathMonitoring: AnyObject {
    var currentStatus: NWPath.Status { get }
    var pathUpdateHandler: (@Sendable (NWPath.Status) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func cancel()
}

private final class NWPathStatusMonitor: NetworkPathMonitoring {
    private let monitor: NWPathMonitor

    var currentStatus: NWPath.Status {
        self.monitor.currentPath.status
    }

    var pathUpdateHandler: (@Sendable (NWPath.Status) -> Void)? {
        didSet {
            let handler = self.pathUpdateHandler
            self.monitor.pathUpdateHandler = { path in
                handler?(path.status)
            }
        }
    }

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
    }

    func start(queue: DispatchQueue) {
        self.monitor.start(queue: queue)
    }

    func cancel() {
        self.monitor.cancel()
    }
}

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isOffline = false

    private let pathMonitor: any NetworkPathMonitoring
    private let session: URLSession
    private let healthCheckURL: URL
    private let queue = DispatchQueue(label: "app.hauptgang.network-monitor")
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "NetworkMonitor")
    private let recoveryIntervalNanoseconds: UInt64
    private let automaticMonitoringEnabled: Bool
    private var probeTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.waitsForConnectivity = false

        self.pathMonitor = NWPathStatusMonitor()
        self.session = URLSession(configuration: configuration)
        self.healthCheckURL = Constants.API.healthCheckURL
        self.recoveryIntervalNanoseconds = 3_000_000_000
        self.automaticMonitoringEnabled = !Self.shouldDisableAutomaticMonitoring

        if self.automaticMonitoringEnabled {
            self.configurePathMonitor()
        }
    }

    init(
        pathMonitor: any NetworkPathMonitoring,
        session: URLSession,
        healthCheckURL: URL = Constants.API.healthCheckURL,
        recoveryIntervalNanoseconds: UInt64 = 3_000_000_000,
        automaticMonitoringEnabled: Bool = true
    ) {
        self.pathMonitor = pathMonitor
        self.session = session
        self.healthCheckURL = healthCheckURL
        self.recoveryIntervalNanoseconds = recoveryIntervalNanoseconds
        self.automaticMonitoringEnabled = automaticMonitoringEnabled

        if self.automaticMonitoringEnabled {
            self.configurePathMonitor()
        }
    }

    /// Recheck backend reachability explicitly, for example during pull-to-refresh.
    func refreshStatus() async {
        guard self.automaticMonitoringEnabled else { return }
        self.cancelScheduledProbe()
        self.cancelRecoveryPolling()
        await self.runHealthCheck(source: "manual-refresh")
    }

    /// Recheck backend reachability when the app becomes active again.
    func appDidBecomeActive() {
        guard self.automaticMonitoringEnabled else { return }
        self.scheduleHealthCheck(source: "app-active")
    }

    func shutdown() {
        self.cancelScheduledProbe()
        self.cancelRecoveryPolling()
        self.pathMonitor.cancel()
    }

    private static var shouldDisableAutomaticMonitoring: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil || environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func configurePathMonitor() {
        self.pathMonitor.pathUpdateHandler = { [weak self] status in
            Task { @MainActor [weak self] in
                self?.handlePathStatusChange(status, source: "nwpath")
            }
        }
        self.pathMonitor.start(queue: self.queue)
        self.handlePathStatusChange(self.pathMonitor.currentStatus, source: "initial")
    }

    private func handlePathStatusChange(_ status: NWPath.Status, source: String) {
        guard status == .satisfied else {
            self.cancelScheduledProbe()
            self.setOffline(true, source: "\(source)-no-path", startRecovery: source != "initial")
            return
        }
        self.scheduleHealthCheck(source: "\(source)-path-restored")
    }

    private func scheduleHealthCheck(source: String) {
        self.cancelScheduledProbe()
        self.probeTask = Task { [weak self] in
            guard let self else { return }
            await self.runHealthCheck(source: source)
        }
    }

    private func cancelScheduledProbe() {
        self.probeTask?.cancel()
        self.probeTask = nil
    }

    private func startRecoveryPollingIfNeeded(source: String) {
        guard self.recoveryTask == nil else { return }

        self.logger.info("Starting offline recovery polling, source=\(source)")
        self.recoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }

            defer { self.recoveryTask = nil }

            while self.isOffline && !Task.isCancelled {
                await self.runHealthCheck(source: "offline-recovery")

                guard self.isOffline else { return }

                do {
                    try await Task.sleep(nanoseconds: self.recoveryIntervalNanoseconds)
                } catch {
                    return
                }
            }
        }
    }

    private func cancelRecoveryPolling() {
        self.recoveryTask?.cancel()
        self.recoveryTask = nil
    }

    private func runHealthCheck(source: String) async {
        var request = URLRequest(url: self.healthCheckURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 5

        do {
            let (_, response) = try await self.session.data(for: request)
            guard !Task.isCancelled else { return }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("Health check returned a non-HTTP response")
                self.setOffline(true, source: "\(source)-invalid-response", startRecovery: true)
                return
            }

            let offline = !(200 ... 299).contains(httpResponse.statusCode)
            self.setOffline(offline, source: "\(source)-status-\(httpResponse.statusCode)", startRecovery: offline)
        } catch is CancellationError {
            // Replaced by a newer probe.
        } catch {
            guard !Task.isCancelled else { return }
            self.logger.error("Health check failed: \(error.localizedDescription)")
            self.setOffline(true, source: "\(source)-request-failed", startRecovery: true)
        }
    }

    private func setOffline(_ offline: Bool, source: String, startRecovery: Bool = false) {
        guard self.isOffline != offline else {
            if offline && startRecovery {
                self.startRecoveryPollingIfNeeded(source: source)
            }
            return
        }

        self.logger.info("Network status changed: \(offline ? "offline" : "online"), source=\(source)")
        self.isOffline = offline

        if offline {
            guard startRecovery else { return }
            self.startRecoveryPollingIfNeeded(source: source)
            return
        }

        self.cancelRecoveryPolling()
    }
}

extension NetworkMonitor: NetworkStatusProviding {}
