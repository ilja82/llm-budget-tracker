import Foundation

// MARK: - Connectivity & Refresh Scheduling

extension BudgetViewModel {
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
            var consecutiveFailures = 0
            while !Task.isCancelled {
                let seconds: Double
                if self?.isInErrorState == true {
                    consecutiveFailures += 1
                    seconds = Double(RefreshBackoff.delaySeconds(
                        consecutiveFailures: consecutiveFailures,
                        intervalSeconds: (self?.updateIntervalMinutes ?? 60) * 60
                    ))
                } else {
                    consecutiveFailures = 0
                    seconds = Double(self?.updateIntervalMinutes ?? 60) * 60
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
