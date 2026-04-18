import Foundation

enum DiagnosticLoggingMode {
    case disabled
    case full
}

struct CachedActivityEnvelope: Codable {
    static let currentVersion = 1
    let version: Int
    let items: [DailySpendData]
}

// MARK: - Model-group helpers

@MainActor
extension BudgetViewModel {
    /// Sorted union of model-group names seen across `dailyActivity`.
    var availableModelGroups: [String] {
        var seen: Set<String> = []
        for entry in dailyActivity {
            guard let groups = entry.breakdown?.modelGroups else { continue }
            for key in groups.keys { seen.insert(key) }
        }
        return seen.sorted()
    }

    /// Return metrics for a given day, optionally scoped to a specific model-group.
    /// nil model → top-level metrics. Missing model-group on a given day → zeros.
    func metrics(for entry: DailySpendData, model: String?) -> SpendMetrics {
        guard let model else { return entry.metrics }
        return entry.breakdown?.modelGroups[model]?.metrics ?? SpendMetrics()
    }

    /// Summed spend per model-group across `range`, ranked descending.
    func modelGroupSpendTotals(range: ModelRange) -> [(model: String, spend: Double)] {
        // Build cutoff in a UTC calendar so it matches the basis of `DailySpendData.date`
        // (UTC "yyyy-MM-dd"). Using `Calendar.current` would roll to the prior UTC day
        // in east-of-UTC zones and leak an extra day into the totals.
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let today = Date()
        let cutoffComponents: DateComponents
        switch range {
        case .thisMonth:
            cutoffComponents = utcCal.dateComponents([.year, .month], from: today)
        case .last28:
            let startOfToday = utcCal.startOfDay(for: today)
            guard let start = utcCal.date(byAdding: .day, value: -27, to: startOfToday) else {
                return []
            }
            cutoffComponents = utcCal.dateComponents([.year, .month, .day], from: start)
        }
        let cutoffStr = String(
            format: "%04d-%02d-%02d",
            cutoffComponents.year ?? 0,
            cutoffComponents.month ?? 0,
            cutoffComponents.day ?? 1
        )
        var totals: [String: Double] = [:]
        for entry in dailyActivity where entry.date >= cutoffStr {
            guard let groups = entry.breakdown?.modelGroups else { continue }
            for (name, group) in groups {
                totals[name, default: 0] += group.metrics.spend
            }
        }
        return totals
            .map { (model: $0.key, spend: $0.value) }
            .sorted { $0.spend > $1.spend }
    }
}

// MARK: - Dev-mode fake data

enum FakeDailyActivity {
    static let modelGroups: [String] = [
        "claude-opus-4-7",
        "claude-haiku-4-5",
        "gpt-oss-120b",
        "glm-4.7-flash",
        "minimax-m2.1"
    ]

    private static let dailyFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static func generate(daysPassed: Int, totalSpend: Double) -> [DailySpendData] {
        guard daysPassed > 0 else { return [] }
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
            let total = SpendMetrics(
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
            return DailySpendData(
                date: dailyFmt.string(from: date),
                metrics: total,
                breakdown: DailyBreakdown(modelGroups: breakdown(for: total))
            )
        }
    }

    /// Split a day's aggregate metrics into per-model shares that sum back to the totals.
    private static func breakdown(for total: SpendMetrics) -> [String: ModelGroupBreakdown] {
        let names = modelGroups
        let shares = (0..<names.count).map { _ in Double.random(in: 0.1...1.0) }
        let totalShare = max(shares.reduce(0, +), 0.0001)
        let fractions = shares.map { $0 / totalShare }

        func partition(_ value: Int) -> [Int] {
            var remaining = value
            var out: [Int] = []
            for (idx, frac) in fractions.enumerated() {
                if idx == fractions.count - 1 {
                    out.append(max(0, remaining))
                } else {
                    let share = Int((Double(value) * frac).rounded())
                    let clamped = max(0, min(share, remaining))
                    out.append(clamped)
                    remaining -= clamped
                }
            }
            return out
        }

        let promptParts = partition(total.promptTokens)
        let completionParts = partition(total.completionTokens)
        let cacheReadParts = partition(total.cacheReadInputTokens)
        let cacheWriteParts = partition(total.cacheCreationInputTokens)
        let successParts = partition(total.successfulRequests)
        let failedParts = partition(total.failedRequests)

        var result: [String: ModelGroupBreakdown] = [:]
        for (idx, name) in names.enumerated() {
            let spendShare = total.spend * fractions[idx]
            let prompt = promptParts[idx]
            let completion = completionParts[idx]
            let cacheRead = cacheReadParts[idx]
            let cacheWrite = cacheWriteParts[idx]
            let success = successParts[idx]
            let failed = failedParts[idx]
            let metrics = SpendMetrics(
                spend: spendShare,
                promptTokens: prompt,
                completionTokens: completion,
                cacheReadInputTokens: cacheRead,
                cacheCreationInputTokens: cacheWrite,
                totalTokens: prompt + completion + cacheRead + cacheWrite,
                successfulRequests: success,
                failedRequests: failed,
                apiRequests: success + failed
            )
            result[name] = ModelGroupBreakdown(metrics: metrics)
        }
        return result
    }
}
