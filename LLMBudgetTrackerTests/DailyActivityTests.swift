import XCTest

final class DailyActivityTests: XCTestCase {
    func testDecodesAllMetrics() throws {
        let metrics = try decodeMetrics("""
            {"spend":3.25,"prompt_tokens":10,"completion_tokens":20,"cache_read_input_tokens":30,
             "cache_creation_input_tokens":40,"total_tokens":100,"successful_requests":5,
             "failed_requests":2,"api_requests":7}
            """)
        XCTAssertEqual(metrics.spend, 3.25)
        XCTAssertEqual(metrics.promptTokens, 10)
        XCTAssertEqual(metrics.completionTokens, 20)
        XCTAssertEqual(metrics.cacheReadInputTokens, 30)
        XCTAssertEqual(metrics.cacheCreationInputTokens, 40)
        XCTAssertEqual(metrics.totalTokens, 100)
        XCTAssertEqual(metrics.successfulRequests, 5)
        XCTAssertEqual(metrics.failedRequests, 2)
        XCTAssertEqual(metrics.apiRequests, 7)
    }

    func testMissingNullAndMalformedMetricsDefaultToZero() throws {
        for input in ["{}", """
            {"spend":"invalid","prompt_tokens":null,"completion_tokens":"invalid",
             "cache_read_input_tokens":[],"cache_creation_input_tokens":{},"total_tokens":null,
             "successful_requests":"invalid","failed_requests":null,"api_requests":"invalid"}
            """] {
            let metrics = try decodeMetrics(input)
            XCTAssertEqual(metrics.spend, 0)
            XCTAssertEqual(metrics.promptTokens, 0)
            XCTAssertEqual(metrics.completionTokens, 0)
            XCTAssertEqual(metrics.cacheReadInputTokens, 0)
            XCTAssertEqual(metrics.cacheCreationInputTokens, 0)
            XCTAssertEqual(metrics.totalTokens, 0)
            XCTAssertEqual(metrics.successfulRequests, 0)
            XCTAssertEqual(metrics.failedRequests, 0)
            XCTAssertEqual(metrics.apiRequests, 0)
        }
    }

    func testModelsTakePrecedenceOverGroupsWithoutDoubleCounting() throws {
        let breakdown = try JSONDecoder().decode(DailyBreakdown.self, from: Data("""
            {"model_groups":{"group":{"metrics":{"spend":9}}},
             "models":{"model-a":{"metrics":{"spend":4}},"model-b":{"metrics":{"spend":5}}}}
            """.utf8))
        XCTAssertEqual(Set(breakdown.perModel.keys), ["model-a", "model-b"])
        XCTAssertEqual(breakdown.perModel.values.reduce(0) { $0 + $1.metrics.spend }, 9)
    }

    func testEmptyModelsFallBackToGroups() {
        let group = ModelGroupBreakdown(metrics: SpendMetrics(spend: 2.5))
        let breakdown = DailyBreakdown(modelGroups: ["group": group])
        XCTAssertEqual(Array(breakdown.perModel.keys), ["group"])
        XCTAssertEqual(breakdown.perModel["group"]?.metrics.spend, 2.5)
    }

    func testMalformedModelsFallBackToGroups() throws {
        let breakdown = try JSONDecoder().decode(DailyBreakdown.self, from: Data("""
            {"models":"invalid","model_groups":{"group":{"metrics":{"spend":2.5}}}}
            """.utf8))
        XCTAssertEqual(breakdown.perModel["group"]?.metrics.spend, 2.5)
    }

    func testMissingBreakdownAndGroupMetricsUseEmptyDefaults() throws {
        let breakdown = try JSONDecoder().decode(DailyBreakdown.self, from: Data("{}".utf8))
        XCTAssertTrue(breakdown.perModel.isEmpty)
        for input in ["{}", #"{"metrics":null}"#, #"{"metrics":"invalid"}"#] {
            let group = try JSONDecoder().decode(ModelGroupBreakdown.self, from: Data(input.utf8))
            XCTAssertEqual(group.metrics.spend, 0)
            XCTAssertEqual(group.metrics.totalTokens, 0)
        }
    }

    func testDailySpendConvertsToUTCLogAndPreservesMetrics() throws {
        let daily = DailySpendData(
            date: "2028-02-29", metrics: SpendMetrics(spend: 3.25, promptTokens: 10, completionTokens: 20)
        )
        let log = try XCTUnwrap(daily.toSpendLog())
        XCTAssertEqual(log.startTime, ISO8601DateFormatter().date(from: "2028-02-29T00:00:00Z"))
        XCTAssertEqual(log.spend, 3.25)
        XCTAssertEqual(log.promptTokens, 10)
        XCTAssertEqual(log.completionTokens, 20)
        XCTAssertNil(log.model)
        XCTAssertFalse(log.id.isEmpty)
    }

    func testInvalidDailyDateDoesNotProduceLog() {
        for date in ["", "not-a-date"] {
            XCTAssertNil(DailySpendData(date: date, metrics: SpendMetrics()).toSpendLog())
        }
    }

    func testMalformedDailyFieldsUseDefaults() throws {
        let daily = try JSONDecoder().decode(
            DailySpendData.self, from: Data(#"{"date":null,"metrics":"invalid","breakdown":null}"#.utf8)
        )
        XCTAssertEqual(daily.date, "")
        XCTAssertEqual(daily.metrics.spend, 0)
        XCTAssertNil(daily.breakdown)
        XCTAssertNil(daily.toSpendLog())
    }

    func testSpendLogCodableRoundTrip() throws {
        let original = SpendLog(
            requestId: "request-fixture", spend: 1.5, startTime: Date(timeIntervalSince1970: 0),
            model: "model-fixture", promptTokens: 10, completionTokens: 20
        )
        let decoded = try JSONDecoder().decode(SpendLog.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.startTime, original.startTime)
        XCTAssertEqual(decoded.spend, original.spend)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.promptTokens, original.promptTokens)
        XCTAssertEqual(decoded.completionTokens, original.completionTokens)
    }

    func testMissingSpendLogFieldsUseSafeDefaults() throws {
        let before = Date()
        let log = try JSONDecoder().decode(SpendLog.self, from: Data("{}".utf8))
        let after = Date()
        XCTAssertNotNil(UUID(uuidString: log.id))
        XCTAssertEqual(log.spend, 0)
        XCTAssertGreaterThanOrEqual(log.startTime, before)
        XCTAssertLessThanOrEqual(log.startTime, after)
        XCTAssertNil(log.model)
        XCTAssertNil(log.promptTokens)
        XCTAssertNil(log.completionTokens)
    }

    private func decodeMetrics(_ input: String) throws -> SpendMetrics {
        try JSONDecoder().decode(SpendMetrics.self, from: Data(input.utf8))
    }
}
