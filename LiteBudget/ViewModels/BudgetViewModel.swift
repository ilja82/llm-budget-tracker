import AppKit
import Foundation
import Observation
import SwiftUI

@Observable
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

    // MARK: - State

    var budgetInfo: BudgetInfo?
    var spendLogs: [SpendLog] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var pacingInfo: PacingInfo?

    var nextRefresh: Date? {
        guard let last = lastUpdated else { return nil }
        return last.addingTimeInterval(Double(updateIntervalMinutes) * 60)
    }

    // MARK: - Computed

    var menuBarText: String {
        guard let info = budgetInfo else { return "$--" }
        switch displayMode {
        case .dollar:
            return info.spend >= 10 ? String(format: "$%.0f", info.spend) : String(format: "$%.2f", info.spend)
        case .percentage:
            guard let max = info.maxBudget, max > 0 else { return "N/A" }
            return String(format: "%.0f%%", (info.spend / max) * 100)
}
    }

    var pacingBarColor: Color {
        guard let pacing = pacingInfo else { return .accentColor }
        return pacing.spend <= pacing.expectedUse ? .green : pacing.spend > pacing.expectedUse * 1.2 ? .red : .orange
    }

    var pacingBarNSColor: NSColor {
        guard let pacing = pacingInfo else { return .controlAccentColor }
        return pacing.spend <= pacing.expectedUse ? .systemGreen : pacing.spend > pacing.expectedUse * 1.2 ? .systemRed : .systemOrange
    }

    var budgetPercentage: Double {
        guard let info = budgetInfo, let max = info.maxBudget, max > 0 else { return 0 }
        return min(1.0, info.spend / max)
    }

    var dailySpend: [(date: Date, amount: Double)] {
        let grouped = Dictionary(grouping: spendLogs) { log in
            Calendar.current.startOfDay(for: log.startTime)
        }
        return grouped
            .map { (date: $0.key, amount: $0.value.reduce(0) { $0 + $1.spend }) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Private

    let devMode = DevModeSettings()
    private let api = APIService()
    private var timerTask: Task<Void, Never>?

    init() { startTimer() }

    deinit { timerTask?.cancel() }

    // MARK: - Actions

    @MainActor
    func refresh() async {
        if devMode.isEnabled {
            injectDevData()
            return
        }
        guard !endpointURL.isEmpty else {
            errorMessage = "Configure the LiteLLM endpoint URL in Settings."
            return
        }
        guard let apiKey = try? KeychainService.load() else {
            errorMessage = "Configure the LiteLLM API key in Settings."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let info = try await api.fetchBudgetInfo(baseURL: endpointURL, apiKey: apiKey)
            budgetInfo = info
            await fetchLogs(apiKey: apiKey, info: info)
            computePacing(from: info)
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Dev Mode

    @MainActor
    private func injectDevData() {
        let daysPassed = max(1, devMode.totalDays - devMode.daysRemaining)
        let resetAt = Calendar.current.date(byAdding: .day, value: devMode.daysRemaining, to: Date()) ?? Date()
        let fakeBudgetInfo = BudgetInfo(
            userId: "dev-mode",
            spend: devMode.spend,
            maxBudget: devMode.maxBudget,
            budgetDuration: "\(devMode.totalDays)d",
            budgetResetAt: resetAt,
            userEmail: "dev@test.local"
        )
        budgetInfo = fakeBudgetInfo
        spendLogs = generateFakeSpendLogs(daysPassed: daysPassed)
        computePacing(from: fakeBudgetInfo)
        lastUpdated = Date()
        errorMessage = nil
    }

    private func generateFakeSpendLogs(daysPassed: Int) -> [SpendLog] {
        guard daysPassed > 0 else { return [] }
        let dailyAvg = devMode.spend / Double(daysPassed)
        return (0..<daysPassed).map { i in
            let daysBack = daysPassed - i - 1
            let date = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
            let variation = Double.random(in: 0.5...1.5)
            return SpendLog(spend: max(0.001, dailyAvg * variation), startTime: date)
        }
    }

    // MARK: - Helpers

    private func fetchLogs(apiKey: String, info: BudgetInfo) async {
        guard let resetAt = info.budgetResetAt, let duration = info.budgetDuration else { return }
        let days = parseDurationDays(duration)
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: resetAt) ?? Date()
        spendLogs = (try? await api.fetchSpendLogs(
            baseURL: endpointURL,
            apiKey: apiKey,
            startDate: startDate
        )) ?? []
    }

    private func computePacing(from info: BudgetInfo) {
        guard let maxBudget = info.maxBudget, maxBudget > 0,
              let resetAt = info.budgetResetAt,
              let durationStr = info.budgetDuration else { return }

        let totalDays = parseDurationDays(durationStr)
        let startDate = Calendar.current.date(byAdding: .day, value: -totalDays, to: resetAt) ?? Date()
        let daysPassed = max(1, Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 1)
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

    /// Parses "30d", "24h", "1m" → number of days
    private func parseDurationDays(_ duration: String) -> Int {
        let s = duration.lowercased()
        if s.hasSuffix("d"), let n = Int(s.dropLast()) { return n }
        if s.hasSuffix("h"), let n = Int(s.dropLast()) { return max(1, n / 24) }
        if s.hasSuffix("m"), let n = Int(s.dropLast()) { return max(1, n * 30) }
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