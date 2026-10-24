import Foundation

/// Response from GET /team/info. Only the team-level budget is consumed.
/// A missing `team_info` fails decoding, which the API service treats as "source unavailable".
struct TeamInfoResponse: Codable {
    let teamInfo: TeamInfoDetails

    enum CodingKeys: String, CodingKey { case teamInfo = "team_info" }
}

struct TeamInfoDetails: Codable {
    let spend: Double?
    let maxBudget: Double?
    let budgetDuration: String?
    let budgetResetAt: Date?

    enum CodingKeys: String, CodingKey {
        case spend
        case maxBudget = "max_budget"
        case budgetDuration = "budget_duration"
        case budgetResetAt = "budget_reset_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spend = try? container.decodeIfPresent(Double.self, forKey: .spend)
        maxBudget = try? container.decodeIfPresent(Double.self, forKey: .maxBudget)
        budgetDuration = try? container.decodeIfPresent(String.self, forKey: .budgetDuration)
        budgetResetAt = try? container.decodeIfPresent(Date.self, forKey: .budgetResetAt)
    }

    func toBudgetInfo() -> BudgetInfo {
        BudgetInfo(
            userId: "",
            spend: spend ?? 0,
            maxBudget: maxBudget,
            budgetDuration: budgetDuration,
            budgetResetAt: budgetResetAt,
            userEmail: nil
        )
    }
}
