import Foundation
import Network

/// Observes system network reachability and reports when connectivity is lost
/// or restored.
///
/// The app launches at login, where the network is frequently not up yet, and
/// can hit transient outages while running. Without this, a failed fetch would
/// leave the app blank until the next scheduled refresh (up to an hour away).
/// `BudgetViewModel` uses these callbacks to recover the moment connectivity
/// returns instead of waiting for the timer.
@MainActor
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.llmbudgettracker.networkmonitor")

    /// Whether the system currently has a satisfied network path. Starts
    /// optimistically `true` so a normal online launch isn't briefly flagged
    /// offline before the first path update arrives; it self-corrects within
    /// milliseconds if the machine is actually offline.
    private(set) var isConnected = true

    /// Called when connectivity transitions from unavailable to available.
    var onBecameReachable: (@MainActor () -> Void)?

    /// Called when connectivity transitions from available to unavailable.
    var onBecameUnreachable: (@MainActor () -> Void)?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(connected: connected)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func handlePathUpdate(connected: Bool) {
        guard connected != isConnected else { return }
        isConnected = connected
        if connected {
            onBecameReachable?()
        } else {
            onBecameUnreachable?()
        }
    }
}
