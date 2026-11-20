import Foundation

extension BudgetViewModel {
    static func temporaryIncreaseFields(_ info: BudgetInfo) -> [APIRequestLog.ExtractedField] {
        let increase = info.temporaryIncrease
        return [
            .init(name: "temp_budget_increase", value: increase.map { String(format: "$%.2f", $0.amount) } ?? "nil"),
            .init(name: "temp_budget_expiry", value: increase.map { $0.expiresAt.ISO8601Format() } ?? "nil")
        ]
    }
}
