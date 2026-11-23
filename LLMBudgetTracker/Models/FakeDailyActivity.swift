import Foundation

enum FakeDailyActivity {
    static let modelGroups: [String] = [
        "Claude Opus 5.5",
        "Claude Sonnet 5.5",
        "Kimi K3.1 Pro",
        "Claude Haiku 5.5",
        "DeepSeek V4.1 Flash 1017",
        "GLM-5.3",
        "GLM-5.3-Flash"
    ]

    private static let dailyFmt = DayKeyFormatter.make()

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
