import Foundation

/// Decode of GET /key/info. LiteLLM nests the key fields under `info`. The team
/// attachment decides whether team budgets are looked up; the key's own budget
/// is one of the candidates for the effective limit.
struct KeyInfoResponse: Codable {
    let info: KeyInfoDetails?

    enum CodingKeys: String, CodingKey { case info }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        info = try container.decodeIfPresent(KeyInfoDetails.self, forKey: .info)
    }
}

/// The `info` object on GET /key/info. Budget fields are decoded leniently so an
/// unexpected shape never hides the team attachment.
struct KeyInfoDetails: Codable {
    let teamId: String?
    let userId: String?
    let spend: Double?
    let maxBudget: Double?
    let budgetDuration: String?
    let budgetResetAt: Date?
    let budgetLimits: [BudgetWindow]?
    let budgetLimitsUsage: [String: BudgetWindowUsage]?

    enum CodingKeys: String, CodingKey {
        case teamId = "team_id"
        case userId = "user_id"
        case spend
        case maxBudget = "max_budget"
        case budgetDuration = "budget_duration"
        case budgetResetAt = "budget_reset_at"
        case budgetLimits = "budget_limits"
        case budgetLimitsUsage = "budget_limits_usage"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teamId = try container.decodeIfPresent(String.self, forKey: .teamId)
        userId = try? container.decodeIfPresent(String.self, forKey: .userId)
        spend = try? container.decodeIfPresent(Double.self, forKey: .spend)
        maxBudget = try? container.decodeIfPresent(Double.self, forKey: .maxBudget)
        budgetDuration = try? container.decodeIfPresent(String.self, forKey: .budgetDuration)
        budgetResetAt = try? container.decodeIfPresent(Date.self, forKey: .budgetResetAt)
        budgetLimits = (try? container.decodeIfPresent([BudgetWindow].self, forKey: .budgetLimits))
            ?? (try? container.decodeIfPresent(String.self, forKey: .budgetLimits))
                .flatMap { try? JSONDecoder().decode([BudgetWindow].self, from: Data($0.utf8)) }
        budgetLimitsUsage = try? container.decodeIfPresent(
            [String: BudgetWindowUsage].self, forKey: .budgetLimitsUsage
        )
    }

    /// One entry per budget window whose current spend LiteLLM reports.
    func windowBudgets() -> [BudgetInfo] {
        (budgetLimits ?? []).compactMap { window in
            guard let spend = budgetLimitsUsage?[window.budgetDuration]?.currentSpend else { return nil }
            return BudgetInfo(
                userId: userId ?? "",
                spend: spend,
                maxBudget: window.maxBudget,
                budgetDuration: window.budgetDuration,
                budgetResetAt: window.resetAt,
                userEmail: nil
            )
        }
    }

    func toBudgetInfo() -> BudgetInfo {
        BudgetInfo(
            userId: userId ?? "",
            spend: spend ?? 0,
            maxBudget: maxBudget,
            budgetDuration: budgetDuration,
            budgetResetAt: budgetResetAt,
            userEmail: nil
        )
    }
}

/// One entry of `budget_limits`: a limit with its own duration and reset time.
struct BudgetWindow: Codable {
    let budgetDuration: String
    let maxBudget: Double
    let resetAt: Date?

    enum CodingKeys: String, CodingKey {
        case budgetDuration = "budget_duration"
        case maxBudget = "max_budget"
        case resetAt = "reset_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        budgetDuration = try container.decode(String.self, forKey: .budgetDuration)
        maxBudget = try container.decode(Double.self, forKey: .maxBudget)
        resetAt = try? container.decodeIfPresent(Date.self, forKey: .resetAt)
    }
}

/// One value of `budget_limits_usage`, keyed by the window's `budget_duration`.
struct BudgetWindowUsage: Codable {
    let currentSpend: Double?

    enum CodingKeys: String, CodingKey {
        case currentSpend = "current_spend"
    }
}
