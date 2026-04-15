import AppKit
import Foundation
import Observation
import SwiftUI

// MARK: - App Load State

enum AppLoadState: Equatable {
    case notConfigured
    case loading
    case refreshing
    case loaded
    case authError
    case networkError
    case invalidData
    case noBudget
    case unknownError
}

// MARK: - Connection Test Result

enum ConnectionTestResult {
    case connected
    case invalidURL
    case authFailed
    case serverUnreachable
    case testFailed

    var message: String {
        switch self {
        case .connected: return "Connected"
        case .invalidURL: return "Invalid URL"
        case .authFailed: return "Authentication failed"
        case .serverUnreachable: return "Server unreachable"
        case .testFailed: return "Connection test failed"
        }
    }

    var isSuccess: Bool { self == .connected }
}

// MARK: - ViewModel

@Observable
@MainActor
// swiftlint:disable:next type_body_length
final class BudgetViewModel {
    // MARK: - Persisted Settings

    var endpointURL: String = UserDefaults.standard.string(forKey: StorageKeys.App.endpointURL) ?? "" {
        didSet { UserDefaults.standard.set(endpointURL, forKey: StorageKeys.App.endpointURL) }
    }

    var updateIntervalMinutes: Int = {
        let stored = UserDefaults.standard.integer(forKey: StorageKeys.App.updateIntervalMinutes)
        return stored > 0 ? stored : 60
    }() {
        didSet {
            UserDefaults.standard.set(updateIntervalMinutes, forKey: StorageKeys.App.updateIntervalMinutes)
            restartTimer()
        }
    }

    var displayMode: MenuBarDisplayMode = {
        let raw = UserDefaults.standard.string(forKey: StorageKeys.App.displayMode) ?? ""
        return MenuBarDisplayMode(rawValue: raw) ?? .dollar
    }() {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: StorageKeys.App.displayMode) }
    }

    var dailyActivityEnabled: Bool = UserDefaults.standard.bool(forKey: StorageKeys.App.dailyActivityEnabled) {
        didSet { UserDefaults.standard.set(dailyActivityEnabled, forKey: StorageKeys.App.dailyActivityEnabled) }
    }

    // MARK: - State

    private(set) var budgetInfo: BudgetInfo? {
        didSet { _safeSpendLine = nil }
    }
    private(set) var spendLogs: [SpendLog] = [] {
        didSet { _dailySpend = nil; _safeSpendLine = nil }
    }
    private(set) var dailyActivity: [DailySpendData] = []
    private(set) var appState: AppLoadState = .loading
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    private(set) var pacingInfo: PacingInfo?

    var nextRefresh: Date? {
        guard let last = lastUpdated else { return nil }
        return last.addingTimeInterval(Double(updateIntervalMinutes) * 60)
    }

    // MARK: - Computed

    var pacingStatus: PacingStatus {
        switch appState {
        case .authError, .networkError, .invalidData, .noBudget, .unknownError, .notConfigured:
            return .unknown
        default:
            return pacingInfo?.status ?? .unknown
        }
    }

    var menuBarText: String {
        guard let info = budgetInfo else { return "$--" }
        switch displayMode {
        case .dollar:
            return String(format: "$%.2f", info.spend)
        case .percentage:
            guard let max = info.maxBudget, max > 0 else { return "N/A" }
            return String(format: "%.0f%%", (info.spend / max) * 100)
        }
    }

    var menuBarTooltip: String {
        switch appState {
        case .notConfigured:
            return "LLM Budget Tracker — Not configured\nOpen Settings to connect."
        case .authError:
            return "Authentication failed\nCheck your API key in Settings."
        case .networkError:
            return "Server unreachable\nCheck your Proxy URL and network."
        case .invalidData:
            return "Invalid response data\nCheck your LiteLLM proxy."
        case .noBudget:
            return "No budget found\nNo budget data is available."
        case .unknownError:
            return "Unknown error\nTry refreshing."
        default:
            break
        }
        guard let info = budgetInfo else {
            return "Status: Unknown"
        }
        let spend = info.spend
        let maxBudget = info.maxBudget ?? 0
        let remaining = max(maxBudget - spend, 0)
        let daysRemaining = pacingInfo?.daysRemaining ?? 0
        let projected = pacingInfo?.predictedTotal ?? 0
        return [
            String(format: "Used: $%.2f of $%.2f", spend, maxBudget),
            String(format: "Remaining: $%.2f", remaining),
            "Reset in: \(daysRemaining) day\(daysRemaining == 1 ? "" : "s")",
            "Status: \(pacingStatus.label)",
            String(format: "Projected by reset: $%.2f", projected)
        ].joined(separator: "\n")
    }

    var pacingBarColor: Color { pacingStatus.color }

    var pacingBarNSColor: NSColor { pacingStatus.nsColor }

    var budgetPercentage: Double {
        guard let info = budgetInfo, let max = info.maxBudget, max > 0 else { return 0 }
        return min(1.0, info.spend / max)
    }

    var dailySpend: [(date: Date, amount: Double)] {
        if let cached = _dailySpend { return cached }
        let grouped = Dictionary(grouping: spendLogs) { log in
            Calendar.current.startOfDay(for: log.startTime)
        }
        let computed = grouped
            .map { (date: $0.key, amount: $0.value.reduce(0) { $0 + $1.spend }) }
            .sorted { $0.date < $1.date }
        _dailySpend = computed
        return computed
    }

    var safeSpendLine: [(date: Date, amount: Double)] {
        if let cached = _safeSpendLine { return cached }
        let computed = computeSafeSpendLine()
        _safeSpendLine = computed
        return computed
    }

    private func computeSafeSpendLine() -> [(date: Date, amount: Double)] {
        guard let info = budgetInfo,
              let maxBudget = info.maxBudget,
              maxBudget > 0,
              let resetAt = info.budgetResetAt,
              let durationStr = info.budgetDuration,
              let totalDays = parseDurationDays(durationStr) else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let billingStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -totalDays, to: resetAt) ?? Date()
        )
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let daysInWindow = calendar.dateComponents([.day], from: billingStart, to: windowEnd).day ?? 0
        guard daysInWindow > 0 else { return [] }

        let spendByDay = Dictionary(uniqueKeysWithValues: dailySpend.map {
            (calendar.startOfDay(for: $0.date), $0.amount)
        })

        var cumulativeSpend = 0.0
        var line: [(date: Date, amount: Double)] = []
        let billingEnd = calendar.startOfDay(for: resetAt)

        for dayOffset in 0..<daysInWindow {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: billingStart) else { continue }
            let daysRemainingInBillingPeriod = max(
                calendar.dateComponents([.day], from: date, to: billingEnd).day ?? 1, 1
            )
            let remainingBudget = max(maxBudget - cumulativeSpend, 0)
            let safeAmount = remainingBudget / Double(daysRemainingInBillingPeriod)
            line.append((date: date, amount: safeAmount))

            if date < today {
                cumulativeSpend += spendByDay[date] ?? 0
            } else {
                cumulativeSpend += safeAmount
            }
        }

        return line
    }

    var relativeLastUpdated: String {
        guard let last = lastUpdated else { return "" }
        let elapsed = Int(-last.timeIntervalSinceNow)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(elapsed / 60) min ago" }
        return "\(elapsed / 3600) hr ago"
    }

    var nextRefreshMinutes: Int? {
        guard let next = nextRefresh else { return nil }
        let seconds = Int(next.timeIntervalSinceNow)
        if seconds <= 0 { return nil }
        return max(1, seconds / 60)
    }

    // MARK: - Private

    let devMode = DevModeSettings()
    let requestLogger = RequestLogger()
    private let api = APIService()
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    @ObservationIgnored private var _dailySpend: [(date: Date, amount: Double)]?
    @ObservationIgnored private var _safeSpendLine: [(date: Date, amount: Double)]?

    private static let dailyFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
    private static let iso8601Display = ISO8601DateFormatter()

    init() {
        if dailyActivityEnabled {
            let cached = loadCachedActivity()
            dailyActivity = cached
            spendLogs = cached.compactMap { $0.toSpendLog() }
        }
        startTimer()
    }

    deinit { timerTask?.cancel() }

    // MARK: - Actions

    @MainActor
    func refresh() async {
        if devMode.isEnabled {
            appState = budgetInfo == nil ? .loading : .refreshing
            isLoading = true
            injectDevData()
            isLoading = false
            appState = devMode.hasMaxBudget ? .loaded : .noBudget
            return
        }
        guard !endpointURL.isEmpty else {
            budgetInfo = nil
            spendLogs = []
            dailyActivity = []
            pacingInfo = nil
            appState = .notConfigured
            isLoading = false
            return
        }
        guard let apiKey = try? KeychainService.load(), !apiKey.isEmpty else {
            budgetInfo = nil
            spendLogs = []
            dailyActivity = []
            pacingInfo = nil
            appState = .notConfigured
            isLoading = false
            return
        }
        guard !isLoading else { return }
        appState = budgetInfo == nil ? .loading : .refreshing
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (info, json, status) = try await withRetry {
                try await api.fetchBudgetInfo(baseURL: endpointURL, apiKey: apiKey)
            }
            await handleBudgetSuccess(info: info, rawJSON: json, statusCode: status, apiKey: apiKey)
        } catch {
            handleRefreshError(error)
        }
    }

    @MainActor
    func setDailyActivityEnabled(_ enabled: Bool) async {
        guard dailyActivityEnabled != enabled else { return }
        dailyActivityEnabled = enabled
        if !enabled {
            clearDailyActivityData()
            return
        }
        await refresh()
    }

    private func handleBudgetSuccess(
        info: BudgetInfo, rawJSON: String, statusCode: Int?, apiKey: String
    ) async {
        logAPIRequest(
            endpoint: "/v2/user/info",
            statusCode: statusCode,
            responseBody: rawJSON,
            errorMessage: nil,
            extractedFields: budgetInfoFields(info)
        )
        guard info.maxBudget != nil else {
            budgetInfo = info
            clearDailyActivityData()
            pacingInfo = nil
            appState = .noBudget
            return
        }
        budgetInfo = info
        if dailyActivityEnabled {
            await fetchLogs(apiKey: apiKey, info: info)
        } else {
            clearDailyActivityData()
        }
        computePacing(from: info)
        lastUpdated = Date()
        appState = .loaded
        errorMessage = nil
    }

    private func handleRefreshError(_ error: Error) {
        let statusCode: Int? = {
            guard let apiErr = error as? APIError,
                  case .httpError(let code) = apiErr else { return nil }
            return code
        }()
        logAPIRequest(
            endpoint: "/v2/user/info",
            statusCode: statusCode,
            responseBody: "",
            errorMessage: error.localizedDescription,
            extractedFields: []
        )
        if let apiError = error as? APIError {
            switch apiError {
            case .httpError(let code) where code == 401 || code == 403: appState = .authError
            case .httpError(429):
                appState = .networkError
                errorMessage = "Rate limited — will retry shortly"
                return
            case .httpError: appState = .networkError
            case .invalidURL: appState = .networkError
            }
        } else {
            appState = (error as NSError).domain == NSURLErrorDomain ? .networkError : .unknownError
        }
        errorMessage = error.localizedDescription
    }

    @MainActor
    func testConnection(url: String, apiKey: String) async -> ConnectionTestResult {
        guard !url.isEmpty, !apiKey.isEmpty else { return .invalidURL }
        guard (try? EndpointSecurity.normalizedBaseURLString(from: url)) != nil else { return .invalidURL }
        do {
            let normalizedURL = try EndpointSecurity.normalizedBaseURLString(from: url)
            _ = try await api.fetchBudgetInfo(baseURL: normalizedURL, apiKey: apiKey)
            return .connected
        } catch let error as APIError {
            switch error {
            case .invalidURL: return .invalidURL
            case .httpError(let code) where code == 401 || code == 403: return .authFailed
            case .httpError: return .serverUnreachable
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain { return .serverUnreachable }
            return .testFailed
        }
    }

    // MARK: - Reset

    @MainActor
    func resetToInitialState() {
        requestLogger.clear()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        KeychainService.delete()
        relaunch()
    }

    private func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: config
        ) { app, error in
            guard app != nil, error == nil else { return }
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - Dev Mode

    @MainActor
    private func injectDevData() {
        let totalDays = max(devMode.totalDays, 1)
        let daysRemaining = min(max(devMode.daysRemaining, 0), totalDays)
        let daysPassed = max(totalDays - daysRemaining, 1)
        // Snap resetAt to the 1st of the next calendar month. billingStart is derived
        // separately from the calendar month start (not from budgetDuration), so it
        // correctly aligns to the 1st regardless of the configured totalDays value.
        let calendar = Calendar.current
        let now = Date()
        var nextMonthComponents = calendar.dateComponents([.year, .month], from: now)
        nextMonthComponents.month = (nextMonthComponents.month ?? 1) + 1
        nextMonthComponents.day = 1
        let resetAt = calendar.date(from: nextMonthComponents)
            ?? calendar.date(byAdding: .day, value: daysRemaining, to: now)
            ?? now
        let fakeBudgetInfo = BudgetInfo(
            userId: "dev-mode",
            spend: devMode.spend,
            maxBudget: devMode.hasMaxBudget ? devMode.maxBudget : nil,
            budgetDuration: devMode.hasReset ? "\(totalDays)d" : nil,
            budgetResetAt: devMode.hasReset ? resetAt : nil,
            userEmail: "dev@test.local"
        )
        budgetInfo = fakeBudgetInfo
        if dailyActivityEnabled {
            let billingStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let actualDaysPassed = max(1, (calendar.dateComponents([.day], from: billingStart, to: now).day ?? 0) + 1)
            let totalChartDays = max(28, actualDaysPassed)
            let scaledSpend = devMode.spend / Double(actualDaysPassed) * Double(totalChartDays)
            dailyActivity = generateFakeDailyActivity(daysPassed: totalChartDays, totalSpend: scaledSpend)
            spendLogs = dailyActivity.compactMap { $0.toSpendLog() }
        } else {
            clearDailyActivityData()
        }
        computePacing(from: fakeBudgetInfo)
        lastUpdated = Date()
        errorMessage = nil
    }

    private func generateFakeDailyActivity(daysPassed: Int, totalSpend: Double) -> [DailySpendData] {
        guard daysPassed > 0 else { return [] }
        let fmt = Self.dailyFmt
        let weights = (0..<daysPassed).map { _ in Double.random(in: 0.5...1.5) }
        let totalWeight = max(weights.reduce(0, +), 0.0001)

        return (0..<daysPassed).map { i in
            let daysBack = daysPassed - i - 1
            let date = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
            let spend = totalSpend > 0
                ? max(0.001, totalSpend * (weights[i] / totalWeight))
                : totalSpend / Double(daysPassed)
            let prompt = Int.random(in: 500...5000)
            let completion = Int.random(in: 100...1000)
            let cacheRead = Int.random(in: 0...2000)
            let cacheWrite = Int.random(in: 0...500)
            let success = Int.random(in: 5...40)
            let failed = Int.random(in: 0...3)
            return DailySpendData(
                date: fmt.string(from: date),
                metrics: SpendMetrics(
                    spend: spend,
                    promptTokens: prompt,
                    completionTokens: completion,
                    cacheReadInputTokens: cacheRead,
                    cacheCreationInputTokens: cacheWrite,
                    totalTokens: prompt + completion + cacheRead + cacheWrite,
                    successfulRequests: success,
                    failedRequests: failed,
                    apiRequests: success + failed
                )
            )
        }
    }

    // MARK: - Helpers

    /// Retries `operation` up to `attempts` times.
    /// - 4xx errors (except 429) are not retried — they won't self-resolve.
    /// - 429 uses a longer back-off delay.
    /// - Task cancellation stops retrying immediately.
    private func withRetry<T>(
        attempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error = URLError(.unknown)
        for attempt in 0..<attempts {
            guard !Task.isCancelled else { throw lastError }
            do {
                return try await operation()
            } catch let error as APIError {
                if case .httpError(let code) = error, code != 429, (400..<500).contains(code) {
                    throw error
                }
                lastError = error
            } catch {
                lastError = error
            }
            if attempt < attempts - 1 {
                let delay: Duration = {
                    if let apiErr = lastError as? APIError,
                       case .httpError(429) = apiErr { return .seconds(30) }
                    return .seconds(2)
                }()
                try? await Task.sleep(for: delay)
            }
        }
        throw lastError
    }

    private func logAPIRequest(
        endpoint: String,
        queryParams: [String: String] = [:],
        statusCode: Int?,
        responseBody: String,
        errorMessage: String?,
        extractedFields: [APIRequestLog.ExtractedField]
    ) {
        let base = endpointURL.trimmingCharacters(in: .init(charactersIn: "/"))
        requestLogger.add(APIRequestLog(
            id: UUID(),
            timestamp: Date(),
            endpoint: endpoint,
            requestURL: base + endpoint,
            requestMethod: "GET",
            requestHeaders: ["x-litellm-api-key": "[REDACTED]"],
            requestQueryParams: sanitizeQueryParams(queryParams),
            statusCode: statusCode,
            responseBody: responseBody,
            errorMessage: errorMessage,
            extractedFields: extractedFields
        ))
    }

    private func fetchLogs(apiKey: String, info: BudgetInfo) async {
        guard info.budgetResetAt != nil else {
            clearDailyActivityData()
            return
        }
        let fmt = Self.dailyFmt
        let today = Date()
        let cache = loadCachedActivity()

        let startDate: Date
        if cache.isEmpty {
            startDate = Calendar.current.date(byAdding: .day, value: -32, to: today) ?? today
        } else {
            let lastDateStr = cache.map(\.date).max() ?? ""
            startDate = fmt.date(from: lastDateStr)
                ?? Calendar.current.date(byAdding: .day, value: -32, to: today)
                ?? today
        }

        let queryParams: [String: String] = [
            "user_id": info.userId,
            "start_date": fmt.string(from: startDate),
            "end_date": fmt.string(from: today),
            "page": "1",
            "page_size": "32"
        ]
        do {
            let (fetched, rawJSON, statusCode) = try await withRetry {
                try await api.fetchDailyActivity(
                    baseURL: endpointURL,
                    apiKey: apiKey,
                    userId: info.userId,
                    startDate: startDate,
                    endDate: today
                )
            }

            let result = mergeAndPersistActivity(cache: cache, fetched: fetched, today: today)
            dailyActivity = result
            spendLogs = result.compactMap { $0.toSpendLog() }

            logAPIRequest(
                endpoint: "/user/daily/activity",
                queryParams: queryParams,
                statusCode: statusCode,
                responseBody: rawJSON,
                errorMessage: nil,
                extractedFields: spendLogsFields(spendLogs)
            )
        } catch {
            logAPIRequest(
                endpoint: "/user/daily/activity",
                queryParams: queryParams,
                statusCode: (error as? APIError).flatMap {
                    if case .httpError(let code) = $0 { return code } else { return nil }
                },
                responseBody: "",
                errorMessage: error.localizedDescription,
                extractedFields: []
            )
            if dailyActivity.isEmpty {
                spendLogs = []
                dailyActivity = []
            }
        }
    }

    private struct CachedActivityEnvelope: Codable {
        static let currentVersion = 1
        let version: Int
        let items: [DailySpendData]
    }

    private func loadCachedActivity() -> [DailySpendData] {
        guard let data = EncryptedStore.data(forKey: StorageKeys.App.dailyActivityCache) else { return [] }
        if let envelope = try? JSONDecoder().decode(CachedActivityEnvelope.self, from: data) {
            guard envelope.version == CachedActivityEnvelope.currentVersion else {
                EncryptedStore.remove(forKey: StorageKeys.App.dailyActivityCache)
                return []
            }
            return envelope.items
        }
        // Legacy: plain array stored before versioning was introduced
        return (try? JSONDecoder().decode([DailySpendData].self, from: data)) ?? []
    }

    private func saveCachedActivity(_ items: [DailySpendData]) {
        let envelope = CachedActivityEnvelope(version: CachedActivityEnvelope.currentVersion, items: items)
        if let encoded = try? JSONEncoder().encode(envelope) {
            EncryptedStore.set(encoded, forKey: StorageKeys.App.dailyActivityCache)
        }
    }

    private func mergeAndPersistActivity(
        cache: [DailySpendData],
        fetched: [DailySpendData],
        today: Date
    ) -> [DailySpendData] {
        var merged: [String: DailySpendData] = [:]
        for entry in cache { merged[entry.date] = entry }
        for entry in fetched { merged[entry.date] = entry }
        let cutoff = Calendar.current.date(byAdding: .day, value: -62, to: today) ?? today
        let cutoffStr = Self.dailyFmt.string(from: cutoff)
        let result = merged.values
            .filter { $0.date >= cutoffStr }
            .sorted { $0.date < $1.date }
        saveCachedActivity(result)
        return result
    }

    func clearDailyActivityData() {
        spendLogs = []
        dailyActivity = []
        EncryptedStore.remove(forKey: StorageKeys.App.dailyActivityCache)
    }

    private func computePacing(from info: BudgetInfo) {
        guard let maxBudget = info.maxBudget, maxBudget > 0,
              let resetAt = info.budgetResetAt,
              let durationStr = info.budgetDuration,
              let totalDays = parseDurationDays(durationStr) else {
            pacingInfo = nil
            return
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -totalDays, to: resetAt) ?? Date()
        let daysPassed = min(
            max(1, Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 1),
            totalDays
        )
        let daysRemaining = max(0, Calendar.current.dateComponents([.day], from: Date(), to: resetAt).day ?? 0)
        let expectedUse = maxBudget * (Double(daysPassed) / Double(totalDays))
        let dailyRate = info.spend / Double(daysPassed)
        let predictedTotal = dailyRate * Double(totalDays)

        pacingInfo = PacingInfo(
            spend: info.spend,
            maxBudget: maxBudget,
            daysRemaining: daysRemaining,
            totalDays: totalDays,
            daysPassed: daysPassed,
            expectedUse: expectedUse,
            predictedTotal: predictedTotal
        )
    }

    private func budgetInfoFields(_ info: BudgetInfo) -> [APIRequestLog.ExtractedField] {
        var fields: [APIRequestLog.ExtractedField] = [
            .init(name: "user_id", value: maskIdentifier(info.userId)),
            .init(name: "spend", value: String(format: "$%.4f", info.spend))
        ]
        if let max = info.maxBudget {
            fields.append(.init(name: "max_budget", value: String(format: "$%.2f", max)))
        } else {
            fields.append(.init(name: "max_budget", value: "nil"))
        }
        fields.append(.init(name: "budget_duration", value: info.budgetDuration ?? "nil"))
        if let reset = info.budgetResetAt {
            fields.append(.init(name: "budget_reset_at", value: Self.iso8601Display.string(from: reset)))
        } else {
            fields.append(.init(name: "budget_reset_at", value: "nil"))
        }
        fields.append(.init(name: "user_email", value: info.userEmail == nil ? "nil" : "[REDACTED]"))
        return fields
    }

    private func spendLogsFields(_ logs: [SpendLog]) -> [APIRequestLog.ExtractedField] {
        let total = logs.reduce(0.0) { $0 + $1.spend }
        let models = Set(logs.compactMap { $0.model }).sorted().joined(separator: ", ")
        let dates = logs.map { $0.startTime }
        var fields: [APIRequestLog.ExtractedField] = [
            .init(name: "log_count", value: "\(logs.count)"),
            .init(name: "total_spend", value: String(format: "$%.4f", total))
        ]
        if let earliest = dates.min(), let latest = dates.max() {
            let fmt = Self.dailyFmt
            let range = "\(fmt.string(from: earliest)) – \(fmt.string(from: latest))"
            fields.append(.init(name: "date_range", value: range))
        }
        if !models.isEmpty {
            fields.append(.init(name: "models", value: models))
        }
        return fields
    }

    /// Parses "30d", "24h", "1m" into a finite number of days.
    /// Returns nil for indefinite periods so callers can avoid open-ended loops.
    private func parseDurationDays(_ duration: String) -> Int? {
        let s = duration.lowercased()
        if s.contains("indefinite") || s == "none" || s == "never" {
            return nil
        }
        if s == "daily" { return 1 }
        if s == "weekly" { return 7 }
        if s == "monthly" { return 30 }
        if s.hasSuffix("d"), let num = Int(s.dropLast()) { return max(num, 1) }
        if s.hasSuffix("s"), let num = Int(s.dropLast()) { return max(1, Int(ceil(Double(num) / 86_400.0))) }
        if s.hasSuffix("h"), let num = Int(s.dropLast()) { return max(1, Int(ceil(Double(num) / 24.0))) }
        if s.hasSuffix("m"), let num = Int(s.dropLast()) { return max(1, Int(ceil(Double(num) / 1_440.0))) }
        if s.hasSuffix("mo"), let num = Int(s.dropLast(2)) { return max(1, num * 30) }
        return 30
    }

    private func startTimer() {
        timerTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                let interval = self.updateIntervalMinutes
                try? await Task.sleep(for: .seconds(Double(interval) * 60))
                guard !Task.isCancelled else { break }
                await self.refresh()
            }
        }
    }

    private func restartTimer() {
        timerTask?.cancel()
        startTimer()
    }

    private func sanitizeQueryParams(_ params: [String: String]) -> [String: String] {
        var sanitized = params
        if let userId = sanitized["user_id"] {
            sanitized["user_id"] = maskIdentifier(userId)
        }
        return sanitized
    }

    private func maskIdentifier(_ value: String) -> String {
        guard value.count > 4 else { return "[REDACTED]" }
        return String(value.prefix(2)) + "…" + String(value.suffix(2))
    }
}
