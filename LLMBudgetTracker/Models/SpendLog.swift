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

struct ModelGroupBreakdown: Codable {
    let metrics: SpendMetrics

    init(metrics: SpendMetrics) {
        self.metrics = metrics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metrics = (try? container.decode(SpendMetrics.self, forKey: .metrics)) ?? SpendMetrics()
    }

    enum CodingKeys: String, CodingKey { case metrics }
}

struct DailyBreakdown: Codable {
    let modelGroups: [String: ModelGroupBreakdown]
    let models: [String: ModelGroupBreakdown]

    /// Per-model breakdown to display. `models` and `model_groups` are alternate
    /// views of the same spend, so prefer the complete `models` and never sum both.
    var perModel: [String: ModelGroupBreakdown] { models.isEmpty ? modelGroups : models }

    init(modelGroups: [String: ModelGroupBreakdown], models: [String: ModelGroupBreakdown] = [:]) {
        self.modelGroups = modelGroups
        self.models = models
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modelGroups = (try? container.decode([String: ModelGroupBreakdown].self, forKey: .modelGroups)) ?? [:]
        models = (try? container.decode([String: ModelGroupBreakdown].self, forKey: .models)) ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case modelGroups = "model_groups"
        case models
    }
}

struct DailySpendData: Codable {
    let date: String       // "yyyy-MM-dd"
    let metrics: SpendMetrics
    let breakdown: DailyBreakdown?

    init(date: String, metrics: SpendMetrics, breakdown: DailyBreakdown? = nil) {
        self.date = date
        self.metrics = metrics
        self.breakdown = breakdown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = (try? container.decode(String.self, forKey: .date)) ?? ""
        metrics = (try? container.decode(SpendMetrics.self, forKey: .metrics)) ?? SpendMetrics()
        breakdown = try? container.decode(DailyBreakdown.self, forKey: .breakdown)
    }

    enum CodingKeys: String, CodingKey { case date, metrics, breakdown }

    /// Convert to SpendLog so downstream consumers (charts, pacing) are unchanged.
    func toSpendLog() -> SpendLog? {
        let f = DayKeyFormatter.make()
        guard let parsedDate = f.date(from: date) else { return nil }
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
    let metadata: DailyActivityPageInfo?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decode([DailySpendData].self, forKey: .results)
        metadata = try? container.decode(DailyActivityPageInfo.self, forKey: .metadata)
    }

    enum CodingKeys: String, CodingKey { case results, metadata }

    var hasMore: Bool { metadata?.hasMore ?? false }
}

struct DailyActivityPageInfo: Codable {
    let hasMore: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasMore = (try? container.decode(Bool.self, forKey: .hasMore)) ?? false
    }

    enum CodingKeys: String, CodingKey { case hasMore = "has_more" }
}

extension SpendMetrics {
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(
            spend: lhs.spend + rhs.spend,
            promptTokens: lhs.promptTokens + rhs.promptTokens,
            completionTokens: lhs.completionTokens + rhs.completionTokens,
            cacheReadInputTokens: lhs.cacheReadInputTokens + rhs.cacheReadInputTokens,
            cacheCreationInputTokens: lhs.cacheCreationInputTokens + rhs.cacheCreationInputTokens,
            totalTokens: lhs.totalTokens + rhs.totalTokens,
            successfulRequests: lhs.successfulRequests + rhs.successfulRequests,
            failedRequests: lhs.failedRequests + rhs.failedRequests,
            apiRequests: lhs.apiRequests + rhs.apiRequests
        )
    }
}

extension DailySpendData {
    /// Joins the results of several pages: LiteLLM pages by database row, so one day can be split across pages.
    static func combinedByDate(_ entries: [Self]) -> [Self] {
        var order: [String] = []
        var byDate: [String: Self] = [:]
        for entry in entries {
            if let existing = byDate[entry.date] {
                byDate[entry.date] = existing.adding(entry)
            } else {
                order.append(entry.date)
                byDate[entry.date] = entry
            }
        }
        return order.compactMap { byDate[$0] }
    }

    private func adding(_ other: Self) -> Self {
        let combined: DailyBreakdown?
        switch (breakdown, other.breakdown) {
        case let (lhs?, rhs?):
            let add = { (first: ModelGroupBreakdown, second: ModelGroupBreakdown) in
                ModelGroupBreakdown(metrics: first.metrics + second.metrics)
            }
            combined = DailyBreakdown(
                modelGroups: lhs.modelGroups.merging(rhs.modelGroups, uniquingKeysWith: add),
                models: lhs.models.merging(rhs.models, uniquingKeysWith: add)
            )
        default:
            combined = breakdown ?? other.breakdown
        }
        return Self(date: date, metrics: metrics + other.metrics, breakdown: combined)
    }
}

struct CachedActivityEnvelope: Codable {
    static let currentVersion = 4
    let version: Int
    let userId: String?
    let items: [DailySpendData]

    init(userId: String?, items: [DailySpendData]) {
        version = Self.currentVersion
        self.userId = userId
        self.items = items
    }

    /// The cached days, or nil for another format or another user. A nil `userId` accepts any user.
    func items(forUser userId: String?) -> [DailySpendData]? {
        guard version == Self.currentVersion else { return nil }
        if let userId, self.userId != userId { return nil }
        return items
    }
}
