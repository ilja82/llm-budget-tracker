import Foundation

enum DiagnosticLoggingMode {
    case disabled
    case full
}

// MARK: - Model-group helpers

@MainActor
extension BudgetViewModel {
    /// Sorted union of model-group names seen across `dailyActivity`.
    var availableModelGroups: [String] {
        var seen: Set<String> = []
        for entry in dailyActivity {
            guard let groups = entry.breakdown?.perModel else { continue }
            for key in groups.keys { seen.insert(key) }
        }
        return seen.sorted()
    }

    /// Return metrics for a given day, optionally scoped to a specific model-group.
    /// nil model → top-level metrics. Missing model-group on a given day → zeros.
    func metrics(for entry: DailySpendData, model: String?) -> SpendMetrics {
        guard let model else { return entry.metrics }
        return entry.breakdown?.perModel[model]?.metrics ?? SpendMetrics()
    }

    /// Summed spend per model-group across `range`, ranked descending.
    func modelGroupSpendTotals(range: ModelRange) -> [(model: String, spend: Double)] {
        guard let dates = range.dateRange(relativeTo: Date()) else { return [] }
        var totals: [String: Double] = [:]
        for entry in dailyActivity where dates.contains(entry.date) {
            guard let groups = entry.breakdown?.perModel else { continue }
            for (name, group) in groups {
                totals[name, default: 0] += group.metrics.spend
            }
        }
        return totals
            .map { (model: $0.key, spend: $0.value) }
            .sorted { $0.spend > $1.spend }
    }
}
