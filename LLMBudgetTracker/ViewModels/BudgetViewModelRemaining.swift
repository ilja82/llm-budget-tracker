import Foundation

extension BudgetViewModel {
    var usageLabel: String {
        showRemaining && displayMode == .percentage && (budgetInfo?.maxBudget ?? 0) > 0 ? "Remaining" : "Used"
    }
}
