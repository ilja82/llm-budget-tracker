import Foundation

extension BudgetViewModel {
    var usageLabel: String {
        budgetInfo?.showsRemaining(showRemaining) == true ? "Remaining" : "Used"
    }
}
