import Foundation

/// A single spend log entry (used internally; sourced from /user/daily/activity)
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

    init(
        requestId: String = UUID().uuidString,
        spend: Double,
        startTime: Date,
        model: String? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil
    ) {
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

// MARK: - /user/daily/activity models

struct SpendMetrics: Codable {
    let spend: Double
    let promptTokens: Int
    let completionTokens: Int
    let cacheReadInputTokens: Int
    let cacheCreationInputTokens: Int
    let totalTokens: Int
    let successfulRequests: Int
    let failedRequests: Int
    let apiRequests: Int

    enum CodingKeys: String, CodingKey {
        case spend
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case totalTokens = "total_tokens"
        case successfulRequests = "successful_requests"
        case failedRequests = "failed_requests"
        case apiRequests = "api_requests"
    }

    init(
        spend: Double = 0,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        cacheReadInputTokens: Int = 0,
        cacheCreationInputTokens: Int = 0,
        totalTokens: Int = 0,
        successfulRequests: Int = 0,
        failedRequests: Int = 0,
        apiRequests: Int = 0
    ) {
        self.spend = spend
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.totalTokens = totalTokens
        self.successfulRequests = successfulRequests
        self.failedRequests = failedRequests
        self.apiRequests = apiRequests
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spend                    = (try? container.decode(Double.self, forKey: .spend)) ?? 0
        promptTokens             = (try? container.decode(Int.self, forKey: .promptTokens)) ?? 0
        completionTokens         = (try? container.decode(Int.self, forKey: .completionTokens)) ?? 0
        cacheReadInputTokens     = (try? container.decode(Int.self, forKey: .cacheReadInputTokens)) ?? 0
        cacheCreationInputTokens = (try? container.decode(Int.self, forKey: .cacheCreationInputTokens)) ?? 0
        totalTokens              = (try? container.decode(Int.self, forKey: .totalTokens)) ?? 0
        successfulRequests       = (try? container.decode(Int.self, forKey: .successfulRequests)) ?? 0
        failedRequests           = (try? container.decode(Int.self, forKey: .failedRequests)) ?? 0
        apiRequests              = (try? container.decode(Int.self, forKey: .apiRequests)) ?? 0
    }
}

struct DailySpendData: Codable {
    let date: String       // "yyyy-MM-dd"
    let metrics: SpendMetrics

    /// Convert to SpendLog so downstream consumers (charts, pacing) are unchanged.
    func toSpendLog() -> SpendLog? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        guard let parsedDate = fmt.date(from: date) else { return nil }
        return SpendLog(
            spend: metrics.spend,
            startTime: parsedDate,
            promptTokens: metrics.promptTokens,
            completionTokens: metrics.completionTokens
        )
    }
}

struct DailyActivityResponse: Codable {
    let results: [DailySpendData]
}
