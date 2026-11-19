import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class UpdateViewModel {
    static let updateCommands = "brew update\nbrew upgrade --cask llm-budget-tracker"
    static let reachabilityRetryInterval: TimeInterval = 3600

    private(set) var availableUpdate: AvailableUpdate?
    private var enabled: Bool

    var isEnabled: Bool {
        get { enabled }
        set { setEnabled(newValue) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let checker: any UpdateChecking
    @ObservationIgnored private let currentVersion: String
    @ObservationIgnored private var scheduleTask: Task<Void, Never>?
    @ObservationIgnored private var networkMonitor: NetworkMonitor?
    @ObservationIgnored private var lastReachabilityRetry: Date?
    @ObservationIgnored private var isChecking = false
    @ObservationIgnored private var hasStarted = false

    init(
        defaults: UserDefaults = .standard,
        checker: any UpdateChecking = UpdateChecker(),
        currentVersion: String = UpdateChecker.appVersion
    ) {
        self.defaults = defaults
        self.checker = checker
        self.currentVersion = currentVersion
        enabled = defaults.object(forKey: StorageKeys.Update.checkEnabled) as? Bool ?? true
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        let monitor = NetworkMonitor()
        monitor.onBecameReachable = { [weak self] in
            self?.handleBecameReachable()
        }
        networkMonitor = monitor
        reevaluate()
        if enabled {
            startSchedule()
        }
    }

    func dismiss() {
        guard let availableUpdate else { return }
        defaults.set(availableUpdate.version, forKey: StorageKeys.Update.dismissedVersion)
        reevaluate()
    }

    func copyCommands() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(Self.updateCommands, forType: .string)
    }

    func reevaluate(now: Date = .now) {
        var update: AvailableUpdate?
        if enabled {
            update = UpdatePolicy.availableUpdate(
                currentVersion: currentVersion,
                release: storedRelease,
                dismissedVersion: defaults.string(forKey: StorageKeys.Update.dismissedVersion),
                now: now
            )
        }
        if update != availableUpdate {
            availableUpdate = update
        }
    }

    func checkIfDue(now: Date = .now) async {
        guard enabled else { return }
        reevaluate(now: now)
        guard UpdatePolicy.isCheckDue(lastCheck: lastCheck, now: now) else { return }
        await performCheck()
    }

    private func setEnabled(_ newValue: Bool) {
        guard newValue != enabled else { return }
        enabled = newValue
        defaults.set(newValue, forKey: StorageKeys.Update.checkEnabled)
        if newValue {
            if hasStarted {
                startSchedule()
            }
        } else {
            scheduleTask?.cancel()
            scheduleTask = nil
        }
        reevaluate()
    }

    private func startSchedule() {
        scheduleTask?.cancel()
        scheduleTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = await self?.runScheduledTick() else { return }
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func runScheduledTick() async -> TimeInterval {
        await checkIfDue()
        let now = Date.now
        return UpdatePolicy.nextWakeDate(lastCheck: lastCheck, release: storedRelease, now: now).timeIntervalSince(now)
    }

    private func handleBecameReachable() {
        let now = Date.now
        guard enabled, !isChecking, UpdatePolicy.isCheckDue(lastCheck: lastCheck, now: now) else { return }
        if let lastReachabilityRetry, now.timeIntervalSince(lastReachabilityRetry) < Self.reachabilityRetryInterval {
            return
        }
        lastReachabilityRetry = now
        Task { [weak self] in
            await self?.performCheck()
        }
    }

    private func performCheck() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        guard let release = try? await checker.fetchLatestRelease(), enabled else { return }
        defaults.set(release.version, forKey: StorageKeys.Update.latestVersion)
        defaults.set(release.publishedAt, forKey: StorageKeys.Update.latestPublishedAt)
        defaults.set(Date.now, forKey: StorageKeys.Update.lastCheck)
        reevaluate()
    }

    private var lastCheck: Date? {
        defaults.object(forKey: StorageKeys.Update.lastCheck) as? Date
    }

    private var storedRelease: ReleaseInfo? {
        guard let version = defaults.string(forKey: StorageKeys.Update.latestVersion),
              let publishedAt = defaults.object(forKey: StorageKeys.Update.latestPublishedAt) as? Date else {
            return nil
        }
        return ReleaseInfo(version: version, publishedAt: publishedAt)
    }
}
