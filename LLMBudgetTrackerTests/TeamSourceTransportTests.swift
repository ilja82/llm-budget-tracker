import XCTest

final class TeamSourceTransportTests: XCTestCase {
    func testTeamInfoTimeoutKeepsTheMemberBudget() async throws {
        let result = try await makeAPI().fetchResolvedBudgetInfo(baseURL: "https://team-info-down.invalid", apiKey: "fixture-key")

        XCTAssertEqual(result.endpoint, "/team/team-fixture/members/me")
        XCTAssertEqual(result.info.maxBudget, 50)
        XCTAssertEqual(result.info.spend, 4)
        XCTAssertTrue(result.limitSources.contains("/team/info: unavailable"), result.limitSources)
    }

    func testMemberTimeoutKeepsTheTeamBudget() async throws {
        let result = try await makeAPI().fetchResolvedBudgetInfo(baseURL: "https://member-down.invalid", apiKey: "fixture-key")

        XCTAssertEqual(result.endpoint, "/team/info")
        XCTAssertEqual(result.info.maxBudget, 80)
        XCTAssertTrue(
            result.limitSources.contains("/team/team-fixture/members/me: unavailable"), result.limitSources
        )
    }

    func testCancelledTeamInfoStillPropagates() async {
        do {
            _ = try await makeAPI().fetchResolvedBudgetInfo(baseURL: "https://team-info-cancelled.invalid", apiKey: "fixture-key")
            XCTFail("A cancelled request must cancel the refresh")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cancelled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTeamInfoRequestSkipsTheMemberRoster() async throws {
        let api = makeAPI()

        _ = try await api.fetchTeamInfo(baseURL: "https://roster.invalid", apiKey: "fixture-key", teamId: "team-fixture")

        let query = try XCTUnwrap(TeamSourceURLProtocol.lastTeamInfoQuery.value)
        let items = URLComponents(string: "https://x.invalid/?\(query)")?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "include_members", value: "false")), query)
        XCTAssertTrue(items.contains(URLQueryItem(name: "team_id", value: "team-fixture")), query)
    }

    private func makeAPI() -> APIService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TeamSourceURLProtocol.self]
        return APIService(configuration: configuration)
    }
}

private final class LockedValue<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T?

    var value: T? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private final class TeamSourceURLProtocol: URLProtocol, @unchecked Sendable {
    static let lastTeamInfoQuery = LockedValue<String>()

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let host = url.host ?? ""
        if url.path == "/team/info" { Self.lastTeamInfoQuery.value = url.query }
        if let error = Self.failure(host: host, path: url.path) {
            client?.urlProtocol(self, didFailWithError: URLError(error))
            return
        }
        guard let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body(path: url.path).utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func failure(host: String, path: String) -> URLError.Code? {
        switch (host, path) {
        case ("team-info-down.invalid", "/team/info"): return .timedOut
        case ("team-info-cancelled.invalid", "/team/info"): return .cancelled
        case ("member-down.invalid", "/team/team-fixture/members/me"): return .networkConnectionLost
        default: return nil
        }
    }

    private static func body(path: String) -> String {
        switch path {
        case "/key/info":
            return #"{"info":{"team_id":"team-fixture","user_id":"fixture-user"}}"#
        case "/team/team-fixture/members/me":
            return #"{"user_id":"fixture-user","spend":4,"litellm_budget_table":{"max_budget":50}}"#
        case "/team/info":
            return #"{"team_id":"team-fixture","team_info":{"spend":9,"max_budget":80}}"#
        case "/v2/user/info":
            return #"{"user_id":"fixture-user","spend":12.5,"max_budget":null}"#
        default:
            return "{}"
        }
    }
}
