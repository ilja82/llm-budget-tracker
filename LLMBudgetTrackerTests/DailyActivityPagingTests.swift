import XCTest

final class DailyActivityPagingTests: XCTestCase {
    func testFollowsAllPagesAndJoinsADaySplitAcrossPages() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PagedActivityURLProtocol.self]
        let api = APIService(configuration: configuration)

        let (activity, rawJSON, status) = try await api.fetchDailyActivity(
            baseURL: "https://paged.invalid", apiKey: "fixture-key", userId: "fixture-user",
            startDate: Date(timeIntervalSince1970: 0), endDate: Date(timeIntervalSince1970: 86_400 * 2)
        )

        XCTAssertEqual(status, 200)
        XCTAssertEqual(activity.map(\.date), ["1970-01-03", "1970-01-02"])
        let split = try XCTUnwrap(activity.first { $0.date == "1970-01-02" })
        XCTAssertEqual(split.metrics.spend, 5, accuracy: 0.000_001)
        XCTAssertEqual(split.metrics.apiRequests, 3)
        XCTAssertEqual(split.breakdown?.models["a"]?.metrics.spend ?? 0, 3, accuracy: 0.000_001)
        XCTAssertEqual(split.breakdown?.models["b"]?.metrics.spend ?? 0, 2, accuracy: 0.000_001)
        XCTAssertEqual(rawJSON.components(separatedBy: "has_more").count, 3, "both page bodies are logged")
    }

    func testRequestsTheLargestPageSize() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PagedActivityURLProtocol.self]
        let api = APIService(configuration: configuration)

        let (activity, _, _) = try await api.fetchDailyActivity(
            baseURL: "https://page-size.invalid", apiKey: "fixture-key", userId: "fixture-user",
            startDate: Date(timeIntervalSince1970: 0), endDate: Date(timeIntervalSince1970: 86_400)
        )

        XCTAssertEqual(activity.first?.metrics.spend, 1)
    }

    func testSinglePageWithoutMetadataIsReadAsTheLastPage() throws {
        let data = Data(#"{"results":[{"date":"1970-01-01","metrics":{"spend":1}}]}"#.utf8)
        let response = try JSONDecoder().decode(DailyActivityResponse.self, from: data)

        XCTAssertFalse(response.hasMore)
        XCTAssertEqual(response.results.count, 1)
    }

    func testCombinedByDateKeepsDaysWithoutBreakdown() {
        let entries = [
            DailySpendData(date: "1970-01-01", metrics: SpendMetrics(spend: 1, totalTokens: 10)),
            DailySpendData(date: "1970-01-01", metrics: SpendMetrics(spend: 2, totalTokens: 5)),
            DailySpendData(date: "1970-01-02", metrics: SpendMetrics(spend: 4))
        ]

        let combined = DailySpendData.combinedByDate(entries)

        XCTAssertEqual(combined.map(\.date), ["1970-01-01", "1970-01-02"])
        XCTAssertEqual(combined[0].metrics.spend, 3, accuracy: 0.000_001)
        XCTAssertEqual(combined[0].metrics.totalTokens, 15)
        XCTAssertNil(combined[0].breakdown)
    }
}

private final class PagedActivityURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body(for: url).utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func body(for url: URL) -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let page = items.first { $0.name == "page" }?.value
        let pageSize = items.first { $0.name == "page_size" }?.value
        if url.host == "page-size.invalid" {
            let spend = pageSize == "1000" ? 1 : 0
            return #"{"results":[{"date":"1970-01-01","metrics":{"spend":\#(spend)}}]}"#
        }
        switch page {
        case "1":
            return #"""
                {"results":[
                {"date":"1970-01-03","metrics":{"spend":7}},
                {"date":"1970-01-02","metrics":{"spend":3,"api_requests":2},
                 "breakdown":{"models":{"a":{"metrics":{"spend":3}}}}}],
                "metadata":{"page":1,"has_more":true}}
                """#
        case "2":
            return #"""
                {"results":[
                {"date":"1970-01-02","metrics":{"spend":2,"api_requests":1},
                 "breakdown":{"models":{"b":{"metrics":{"spend":2}}}}}],
                "metadata":{"page":2,"has_more":false}}
                """#
        default:
            return #"{"results":[{"date":"1970-01-09","metrics":{"spend":99}}],"metadata":{"has_more":false}}"#
        }
    }
}
