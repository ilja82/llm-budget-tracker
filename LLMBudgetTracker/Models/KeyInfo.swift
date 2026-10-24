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

    enum CodingKeys: String, CodingKey {
        case teamId = "team_id"
        case userId = "user_id"
        case spend
        case maxBudget = "max_budget"
        case budgetDuration = "budget_duration"
        case budgetResetAt = "budget_reset_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teamId = try container.decodeIfPresent(String.self, forKey: .teamId)
        userId = try? container.decodeIfPresent(String.self, forKey: .userId)
        spend = try? container.decodeIfPresent(Double.self, forKey: .spend)
        maxBudget = try? container.decodeIfPresent(Double.self, forKey: .maxBudget)
        budgetDuration = try? container.decodeIfPresent(String.self, forKey: .budgetDuration)
        budgetResetAt = try? container.decodeIfPresent(Date.self, forKey: .budgetResetAt)
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
