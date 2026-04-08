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
final class BudgetViewModel {

    // MARK: - Persisted Settings

    var endpointURL: String = UserDefaults.standard.string(forKey: "endpointURL") ?? "" {
        didSet { UserDefaults.standard.set(endpointURL, forKey: "endpointURL") }
    }

    var updateIntervalMinutes: Int = {
        let stored = UserDefaults.standard.integer(forKey: "updateIntervalMinutes")
        return stored > 0 ? stored : 60
    }() {
        didSet {
            UserDefaults.standard.set(updateIntervalMinutes, forKey: "updateIntervalMinutes")
            restartTimer()
        }
    }

    var displayMode: MenuBarDisplayMode = {
        let raw = UserDefaults.standard.string(forKey: "displayMode") ?? ""
        return MenuBarDisplayMode(rawValue: raw) ?? .dollar
    }() {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode") }
    }

    var chartDays: Int = {
        let stored = UserDefaults.standard.integer(forKey: "chartDays")
        return stored > 0 ? stored : 14
    }() {
        didSet {
            UserDefaults.standard.set(chartDays, forKey: "chartDays")
            _safeSpendLine = nil
        }
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

    var pacingBarColor: Color {
        switch appState {
        case .authError, .networkError, .invalidData, .noBudget, .unknownError, .notConfigured:
            return Color(nsColor: .systemGray)
        default:
            break
        }
        switch pacingStatus {
        case .underPace: return .green
        case .onTrack: return .green
        case .nearLimit: return .yellow
        case .overPace: return .red
        case .unknown: return Color(nsColor: .systemGray)
        }
    }

    var pacingBarNSColor: NSColor {
        switch appState {
        case .authError, .networkError, .invalidData, .noBudget, .unknownError, .notConfigured:
            return .systemGray
        default:
            break
        }
        switch pacingStatus {
        case .underPace: return .systemGreen
        case .onTrack: return .systemGreen
        case .nearLimit: return .systemYellow
        case .overPace: return .systemRed
        case .unknown: return .systemGray
        }
    }

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
        let chartStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -chartDays, to: Date()) ?? Date()
        )
        // Window starts at whichever is later: billing period start or chart window start
        let windowStart = max(billingStart, chartStart)
        // Cap the window at today (inclusive) so the chart doesn't extend into future dates
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let daysInWindow = calendar.dateComponents([.day], from: windowStart, to: windowEnd).day ?? 0
        guard daysInWindow > 0 else { return [] }

        let spendByDay = Dictionary(uniqueKeysWithValues: dailySpend.map {
            (calendar.startOfDay(for: $0.date), $0.amount)
        })

        // If the window starts after the billing period start, we don't have spend data
        // for the days before the window. Estimate that pre-window spend as:
        //   total billing spend (info.spend) − known spend for in-window past days
        var cumulativeSpend: Double
        if chartStart <= billingStart {
            cumulativeSpend = 0.0
        } else {
            let knownWindowPastSpend = spendByDay
                .filter { $0.key >= windowStart && $0.key < today }
                .values.reduce(0, +)
            cumulativeSpend = max(info.spend - knownWindowPastSpend, 0)
        }

        var line: [(date: Date, amount: Double)] = []

        let billingEnd = calendar.startOfDay(for: resetAt)

        for dayOffset in 0..<daysInWindow {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: windowStart) else { continue }
            // Use days remaining in the full billing period so the optimum is accurate
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

    @ObservationIgnored private var _dailySpend: [(date: Date, amount: Double)]? = nil
    @ObservationIgnored private var _safeSpendLine: [(date: Date, amount: Double)]? = nil

    private static let dailyFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let iso8601Display = ISO8601DateFormatter()

    init() { startTimer() }

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
        appState = budgetInfo == nil ? .loading : .refreshing
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (info, json, status) = try await api.fetchBudgetInfo(baseURL: endpointURL, apiKey: apiKey)
            await handleBudgetSuccess(info: info, rawJSON: json, statusCode: status, apiKey: apiKey)
        } catch {
            handleRefreshError(error)
        }
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
            spendLogs = []
            dailyActivity = []
            pacingInfo = nil
            appState = .noBudget
            return
        }
        budgetInfo = info
        await fetchLogs(apiKey: apiKey, info: info)
        computePacing(from: info)
        lastUpdated = Date()
        appState = .loaded
        errorMessage = nil
    }

    private func handleRefreshError(_ error: Error) {
        let statusCode: Int? = {
            guard let apiErr = error as? APIError,
                  case .httpError(let c) = apiErr else { return nil }
            return c
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
        guard url.hasPrefix("http://") || url.hasPrefix("https://") else { return .invalidURL }
        do {
            _ = try await api.fetchBudgetInfo(baseURL: url, apiKey: apiKey)
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
        let defaults = UserDefaults.standard
        for key in ["endpointURL", "updateIntervalMinutes", "displayMode", "chartDays",
                    "devMode.isEnabled", "devMode.spend", "devMode.hasMaxBudget", "devMode.maxBudget",
                    "devMode.hasReset", "devMode.daysRemaining", "devMode.totalDays",
                    "devMode.unlocked", "devLog.requests"] {
            defaults.removeObject(forKey: key)
        }
        KeychainService.delete()
        requestLogger.clear()

        endpointURL = ""
        updateIntervalMinutes = 60
        displayMode = .dollar
        chartDays = 14
        devMode.isEnabled = false
        devMode.spend = 45.50
        devMode.hasMaxBudget = true
        devMode.maxBudget = 100.00
        devMode.hasReset = true
        devMode.daysRemaining = 12
        devMode.totalDays = 30

        budgetInfo = nil
        spendLogs = []
        dailyActivity = []
        pacingInfo = nil
        errorMessage = nil
        lastUpdated = nil
        appState = .notConfigured
    }

    // MARK: - Dev Mode

    @MainActor
    private func injectDevData() {
        let totalDays = max(devMode.totalDays, 1)
        let daysRemaining = min(max(devMode.daysRemaining, 0), totalDays)
        let daysPassed = max(totalDays - daysRemaining, 1)
        let resetAt = Calendar.current.date(byAdding: .day, value: daysRemaining, to: Date()) ?? Date()
        let fakeBudgetInfo = BudgetInfo(
            userId: "dev-mode",
            spend: devMode.spend,
            maxBudget: devMode.hasMaxBudget ? devMode.maxBudget : nil,
            budgetDuration: devMode.hasReset ? "\(totalDays)d" : nil,
            budgetResetAt: devMode.hasReset ? resetAt : nil,
            userEmail: "dev@test.local"
        )
        budgetInfo = fakeBudgetInfo
        dailyActivity = generateFakeDailyActivity(daysPassed: daysPassed, totalSpend: devMode.spend)
        spendLogs = dailyActivity.compactMap { $0.toSpendLog() }
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
            let spend = totalSpend > 0 ? max(0.001, totalSpend * (weights[i] / totalWeight)) : totalSpend / Double(daysPassed)
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
            requestQueryParams: queryParams,
            statusCode: statusCode,
            responseBody: responseBody,
            errorMessage: errorMessage,
            extractedFields: extractedFields
        ))
    }

    private func fetchLogs(apiKey: String, info: BudgetInfo) async {
        guard info.budgetResetAt != nil else {
            spendLogs = []
            return
        }
        let startDate = Calendar.current.date(byAdding: .day, value: -chartDays, to: Date()) ?? Date()
        let endDate = Date()
        let fmt = Self.dailyFmt
        let queryParams: [String: String] = [
            "user_id": info.userId,
            "start_date": fmt.string(from: startDate),
            "end_date": fmt.string(from: endDate),
            "page": "1",
            "page_size": "32"
        ]
        do {
            let (activityData, rawJSON, statusCode) = try await api.fetchDailyActivity(
                baseURL: endpointURL,
                apiKey: apiKey,
                userId: info.userId,
                startDate: startDate,
                endDate: endDate
            )
            dailyActivity = activityData
            spendLogs = activityData.compactMap { $0.toSpendLog() }
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
                statusCode: (error as? APIError).flatMap { if case .httpError(let c) = $0 { return c } else { return nil } },
                responseBody: "",
                errorMessage: error.localizedDescription,
                extractedFields: []
            )
            spendLogs = []
            dailyActivity = []
        }
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
            .init(name: "user_id", value: info.userId),
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
        fields.append(.init(name: "user_email", value: info.userEmail ?? "nil"))
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
            fields.append(.init(name: "date_range", value: "\(fmt.string(from: earliest)) – \(fmt.string(from: latest))"))
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
        if s.hasSuffix("d"), let n = Int(s.dropLast()) { return max(n, 1) }
        if s.hasSuffix("s"), let n = Int(s.dropLast()) { return max(1, Int(ceil(Double(n) / 86_400.0))) }
        if s.hasSuffix("h"), let n = Int(s.dropLast()) { return max(1, Int(ceil(Double(n) / 24.0))) }
        if s.hasSuffix("m"), let n = Int(s.dropLast()) { return max(1, Int(ceil(Double(n) / 1_440.0))) }
        if s.hasSuffix("mo"), let n = Int(s.dropLast(2)) { return max(1, n * 30) }
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
}
