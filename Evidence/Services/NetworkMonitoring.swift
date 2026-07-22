import Foundation
import Network

/// Reports whether the device currently has a usable network path.
protocol NetworkStatusProviding: AnyObject {
    var isConnected: Bool { get }
}

/// Monitors connectivity with `NWPathMonitor`.
@MainActor
final class NetworkMonitor: NetworkStatusProviding {
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    private(set) var isConnected: Bool = true

    init(monitor: NWPathMonitor = NWPathMonitor(), queue: DispatchQueue = DispatchQueue(label: "evidence.network.monitor")) {
        self.monitor = monitor
        self.queue = queue
        start()
    }

    deinit {
        monitor.cancel()
    }

    private func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

/// Fixed connectivity for tests and previews.
final class FixedNetworkMonitor: NetworkStatusProviding, @unchecked Sendable {
    var isConnected: Bool

    init(isConnected: Bool) {
        self.isConnected = isConnected
    }
}
