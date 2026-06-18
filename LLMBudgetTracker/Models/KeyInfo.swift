import Foundation

/// Minimal decode of GET /key/info. We only need the key's team attachment to
/// decide where its budget is tracked: LiteLLM tracks a team-attached key's
/// budget per team-member, not on the user record from /v2/user/info.
/// LiteLLM nests the key fields under `info`.
struct KeyInfoResponse: Codable {
    let info: KeyInfoDetails?

    enum CodingKeys: String, CodingKey { case info }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        info = try container.decodeIfPresent(KeyInfoDetails.self, forKey: .info)
    }
}

/// The `info` object on GET /key/info — only the team attachment is consumed.
struct KeyInfoDetails: Codable {
    let teamId: String?

    enum CodingKeys: String, CodingKey {
        case teamId = "team_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teamId = try container.decodeIfPresent(String.self, forKey: .teamId)
    }
}
