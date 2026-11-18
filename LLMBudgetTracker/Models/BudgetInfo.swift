import Foundation

/// Response from GET /v2/user/info
struct BudgetInfo: Codable {
    let userId: String
    let spend: Double
    let maxBudget: Double?
    let budgetDuration: String?
    let budgetResetAt: Date?
    let userEmail: String?

    var hasBudgetLimit: Bool { maxBudget != nil }

    /// Daily activity uses a rolling date window, independent of budget/reset configuration.
    var canLoadDailyActivity: Bool { !userId.isEmpty }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case spend
        case maxBudget = "max_budget"
        case budgetDuration = "budget_duration"
        case budgetResetAt = "budget_reset_at"
        case userEmail = "user_email"
    }

    init(
        userId: String,
        spend: Double,
        maxBudget: Double?,
        budgetDuration: String?,
        budgetResetAt: Date?,
        userEmail: String?
    ) {
        self.userId = userId
        self.spend = spend
        self.maxBudget = maxBudget
        self.budgetDuration = budgetDuration
        self.budgetResetAt = budgetResetAt
        self.userEmail = userEmail
    }

    /// Budget left before LiteLLM rejects requests; infinite without a limit.
    var remainingBudget: Double {
        guard let maxBudget else { return .infinity }
        return max(maxBudget - spend, 0)
    }

    func usageText(_ mode: MenuBarDisplayMode) -> String {
        if mode == .percentage, let maxBudget, maxBudget > 0 {
            return String(format: "%.0f%%", (spend / maxBudget) * 100)
        }
        return String(format: "$%.2f", spend)
    }

    func withUserId(_ userId: String) -> Self {
        Self(
            userId: userId,
            spend: spend,
            maxBudget: maxBudget,
            budgetDuration: budgetDuration,
            budgetResetAt: budgetResetAt,
            userEmail: userEmail
        )
    }

    func withoutBudgetLimit() -> Self {
        Self(
            userId: userId,
            spend: spend,
            maxBudget: nil,
            budgetDuration: nil,
            budgetResetAt: nil,
            userEmail: userEmail
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        spend = (try? container.decode(Double.self, forKey: .spend)) ?? 0
        maxBudget = try container.decodeIfPresent(Double.self, forKey: .maxBudget)
        budgetDuration = try container.decodeIfPresent(String.self, forKey: .budgetDuration)
        budgetResetAt = try container.decodeIfPresent(Date.self, forKey: .budgetResetAt)
        userEmail = try container.decodeIfPresent(String.self, forKey: .userEmail)
    }
}
