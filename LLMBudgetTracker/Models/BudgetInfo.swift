import Foundation

/// Response from GET /v2/user/info
struct BudgetInfo: Codable {
    let userId: String
    let spend: Double
    let maxBudget: Double?
    let budgetDuration: String?
    let budgetResetAt: Date?
    let userEmail: String?
    /// The active LiteLLM temporary increase that `maxBudget` already includes.
    let temporaryIncrease: TemporaryBudgetIncrease?

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
        userEmail: String?,
        temporaryIncrease: TemporaryBudgetIncrease? = nil
    ) {
        self.userId = userId
        self.spend = spend
        self.maxBudget = maxBudget
        self.budgetDuration = budgetDuration
        self.budgetResetAt = budgetResetAt
        self.userEmail = userEmail
        self.temporaryIncrease = temporaryIncrease
    }

    /// Budget left before LiteLLM rejects requests; infinite without a limit.
    var remainingBudget: Double {
        guard let maxBudget else { return .infinity }
        return max(maxBudget - spend, 0)
    }

    func usageText(_ mode: MenuBarDisplayMode) -> String {
        usageText(mode, showRemaining: false)
    }

    func usageText(_ mode: MenuBarDisplayMode, showRemaining: Bool) -> String {
        if mode == .percentage, let maxBudget, maxBudget > 0 {
            let share = showRemaining ? max(maxBudget - spend, 0) / maxBudget : spend / maxBudget
            return String(format: "%.0f%%", share * 100)
        }
        return String(format: "$%.2f", showsRemaining(showRemaining) ? remainingBudget : spend)
    }

    /// Whether the menu bar shows the remaining budget; it needs a budget limit.
    func showsRemaining(_ showRemaining: Bool) -> Bool {
        showRemaining && hasBudgetLimit
    }

    /// Whether the popover headline shows the remaining budget: the opposite of the menu bar.
    func popoverShowsRemaining(menuShowsRemaining showRemaining: Bool) -> Bool {
        hasBudgetLimit && !showRemaining
    }

    func fillFraction(showRemaining: Bool) -> Double {
        guard let maxBudget, maxBudget > 0 else { return 0 }
        let used = min(1.0, spend / maxBudget)
        return showRemaining ? min(1.0, 1.0 - used) : used
    }

    func withUserId(_ userId: String) -> Self {
        Self(
            userId: userId,
            spend: spend,
            maxBudget: maxBudget,
            budgetDuration: budgetDuration,
            budgetResetAt: budgetResetAt,
            userEmail: userEmail,
            temporaryIncrease: temporaryIncrease
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
        temporaryIncrease = nil
    }
}
