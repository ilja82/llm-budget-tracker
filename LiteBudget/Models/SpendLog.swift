import Foundation

/// A single spend log entry from GET /spend/logs/v2
struct SpendLog: Codable, Identifiable {
    let requestId: String
    let spend: Double
    let startTime: Date
    let model: String?
    let promptTokens: Int?
    let completionTokens: Int?

    var id: String { requestId }

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case spend
        case startTime
        case model
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }

    init(requestId: String = UUID().uuidString, spend: Double, startTime: Date, model: String? = nil, promptTokens: Int? = nil, completionTokens: Int? = nil) {
        self.requestId = requestId
        self.spend = spend
        self.startTime = startTime
        self.model = model
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requestId = (try? container.decode(String.self, forKey: .requestId)) ?? UUID().uuidString
        spend = (try? container.decode(Double.self, forKey: .spend)) ?? 0
        startTime = (try? container.decode(Date.self, forKey: .startTime)) ?? Date()
        model = try container.decodeIfPresent(String.self, forKey: .model)
        promptTokens = try container.decodeIfPresent(Int.self, forKey: .promptTokens)
        completionTokens = try container.decodeIfPresent(Int.self, forKey: .completionTokens)
    }
}

/// Wrapper for paginated response
struct SpendLogsResponse: Codable {
    let data: [SpendLog]
}