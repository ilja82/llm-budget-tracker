import Foundation

/// Response from GET /team/{team_id}/members/me — the caller's own team-membership row.
/// When a key is attached to a team, the budget (spend + max) is tracked here, per
/// team-member, instead of on the user record returned by /v2/user/info.
struct TeamMemberInfoResponse: Codable {
    let userId: String
    let spend: Double
    let userEmail: String?
    let litellmBudgetTable: LiteLLMBudgetTable?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case spend
        case userEmail = "user_email"
        case litellmBudgetTable = "litellm_budget_table"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = (try? container.decode(String.self, forKey: .userId)) ?? ""
        spend = (try? container.decode(Double.self, forKey: .spend)) ?? 0
        userEmail = try container.decodeIfPresent(String.self, forKey: .userEmail)
        litellmBudgetTable = try container.decodeIfPresent(LiteLLMBudgetTable.self, forKey: .litellmBudgetTable)
    }

    /// Map the team-member row onto BudgetInfo so pacing/UI consume it unchanged.
    /// A missing budget table (or max_budget) yields maxBudget == nil, which the
    /// view model treats as the existing `.noBudget` state.
    func toBudgetInfo() -> BudgetInfo {
        BudgetInfo(
            userId: userId,
            spend: spend,
            maxBudget: litellmBudgetTable?.maxBudget,
            budgetDuration: litellmBudgetTable?.budgetDuration,
            budgetResetAt: litellmBudgetTable?.budgetResetAt,
            userEmail: userEmail
        )
    }
}

/// Per-team-member budget record nested on the membership row. Subset of LiteLLM's
/// LiteLLM_BudgetTableFull / LiteLLM_BudgetTable (either shape decodes — all optional).
struct LiteLLMBudgetTable: Codable {
    let maxBudget: Double?
    let budgetDuration: String?
    let budgetResetAt: Date?

    enum CodingKeys: String, CodingKey {
        case maxBudget = "max_budget"
        case budgetDuration = "budget_duration"
        case budgetResetAt = "budget_reset_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxBudget = try container.decodeIfPresent(Double.self, forKey: .maxBudget)
        budgetDuration = try container.decodeIfPresent(String.self, forKey: .budgetDuration)
        budgetResetAt = try container.decodeIfPresent(Date.self, forKey: .budgetResetAt)
    }
}
