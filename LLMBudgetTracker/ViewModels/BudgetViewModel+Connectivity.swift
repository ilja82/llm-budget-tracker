import Foundation

// MARK: - Connectivity & Refresh Scheduling

extension BudgetViewModel {
    /// Backoff bounds used to poll faster than the normal update interval while
    /// the last refresh is failing (e.g. an outage), capped so we never hammer.
    private static let baseRetrySeconds: Double = 30
    private static let maxRetrySeconds: Double = 300

    /// The state to show while a refresh is in flight. When offline we surface the
    /// "Waiting for connection…" card instead of a spinner that would otherwise stay
    /// up for the whole outage (the request waits via `waitsForConnectivity`).
    func inProgressState() -> AppLoadState {
        guard networkMonitor.isConnected else { return .offline }
        return budgetInfo == nil ? .loading : .refreshing
    }

    /// Whether the most recent refresh left us in a recoverable failure state
    /// (used to drive faster retry polling in `startTimer`).
    private var isInErrorState: Bool {
        switch appState {
        case .offline, .networkError, .unknownError:
            return true
        default:
            return false
        }
    }

    func startTimer() {
        timerTask = Task { [weak self] in
            await self?.refresh()
            var retryDelay = Self.baseRetrySeconds
            while !Task.isCancelled {
                let seconds: Double
                if self?.isInErrorState == true {
                    // Last refresh failed: poll faster with capped exponential backoff
                    // so we recover during an outage without waiting the full interval.
                    seconds = retryDelay
                    retryDelay = min(retryDelay * 2, Self.maxRetrySeconds)
                } else {
                    seconds = Double(self?.updateIntervalMinutes ?? 60) * 60
                    retryDelay = Self.baseRetrySeconds
                }
                try? await Task.sleep(for: .seconds(seconds))
                if Task.isCancelled { break }
                await self?.refresh()
            }
        }
    }

    func restartTimer() {
        timerTask?.cancel()
        startTimer()
    }

    /// Wires reachability callbacks so the app recovers the moment connectivity
    /// returns (after a launch-at-login boot or a mid-session outage) instead of
    /// waiting for the next scheduled refresh.
    func setupNetworkMonitor() {
        networkMonitor.onBecameReachable = { [weak self] in
            guard let self else { return }
            // Connectivity returned — recover immediately, but only if we're
            // showing stale/failed data. A concurrent timer fire is de-duped by
            // the `isLoading` guard inside `refresh()`.
            switch appState {
            case .offline, .networkError, .unknownError:
                Task { await self.refresh() }
            default:
                if lastUpdated == nil { Task { await self.refresh() } }
            }
        }
        networkMonitor.onBecameUnreachable = { [weak self] in
            // Reflect the outage right away (without clobbering more important states).
            self?.enterOfflineStateIfNeeded()
        }
    }
}
