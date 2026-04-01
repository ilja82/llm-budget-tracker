import Foundation

/// Computed pacing information derived from BudgetInfo
struct PacingInfo {
    let spend: Double
    let maxBudget: Double
    let daysRemaining: Int
    let totalDays: Int
    let daysPassed: Int
    let expectedUse: Double
    let predictedTotal: Double

    var percentageUsed: Double {
        guard maxBudget > 0 else { return 0 }
        return min(1.0, spend / maxBudget)
    }

    var isOverPacing: Bool {
        spend > expectedUse
    }

    /// Positive = over budget pace; negative = under
    var pacingDelta: Double {
        spend - expectedUse
    }
}