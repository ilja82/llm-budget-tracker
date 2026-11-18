import XCTest

final class BudgetUsageTests: XCTestCase {
    func testTeamWithoutBudgetFallsBackToUserUsage() async throws {
        let result = try await fetch(scenario: "no-team-budget")

        XCTAssertEqual(result.endpoint, "/v2/user/info")
        XCTAssertEqual(result.info.spend, 12.5)
        XCTAssertNil(result.info.maxBudget)
        XCTAssertTrue(result.info.canLoadDailyActivity)
    }

    func testTeamBudgetRemainsAuthoritative() async throws {
        let result = try await fetch(scenario: "team-budget")

        XCTAssertEqual(result.endpoint, "/team/team-fixture/members/me")
        XCTAssertEqual(result.info.spend, 4)
        XCTAssertEqual(result.info.maxBudget, 50)
    }

    func testUserBudgetIsIgnoredForTeamKeys() async throws {
        let result = try await fetch(scenario: "user-budget")

        XCTAssertEqual(result.endpoint, "/v2/user/info")
        XCTAssertNil(result.info.maxBudget)
        XCTAssertNil(result.info.budgetDuration)
        XCTAssertEqual(result.info.spend, 12.5)
        XCTAssertEqual(result.limitSources, "")
    }

    func testUserBudgetIsUsedForPersonalKeys() async throws {
        let result = try await fetch(scenario: "personal-user-budget")

        XCTAssertEqual(result.endpoint, "/v2/user/info")
        XCTAssertEqual(result.info.maxBudget, 100)
        XCTAssertEqual(result.info.spend, 12.5)
    }

    func testLeastRemainingBudgetWinsOverLowestLimit() async throws {
        let result = try await fetch(scenario: "remaining")

        XCTAssertEqual(result.endpoint, "/team/team-fixture/members/me")
        XCTAssertEqual(result.info.maxBudget, 100)
        XCTAssertEqual(result.info.spend, 99)
        XCTAssertEqual(result.info.remainingBudget, 1)
    }

    func testTeamDefaultMemberBudgetAppliesWithoutOwnMemberLimit() async throws {
        let result = try await fetch(scenario: "member-default")

        XCTAssertEqual(result.endpoint, "/team/team-fixture/members/me")
        XCTAssertEqual(result.info.maxBudget, 30)
        XCTAssertEqual(result.info.spend, 6)
        XCTAssertEqual(result.info.budgetDuration, "1mo")
    }

    func testZeroTeamDefaultMemberBudgetIsIgnored() async throws {
        let result = try await fetch(scenario: "member-default-zero")

        XCTAssertEqual(result.endpoint, "/v2/user/info")
        XCTAssertNil(result.info.maxBudget)
    }

    func testKeyBudgetWindowWithLeastRemainingWins() async throws {
        let result = try await fetch(scenario: "key-window")

        XCTAssertEqual(result.endpoint, "/key/info budget_limits[1d]")
        XCTAssertEqual(result.info.maxBudget, 5)
        XCTAssertEqual(result.info.spend, 4)
        XCTAssertEqual(result.info.budgetDuration, "1d")
        XCTAssertNotNil(result.info.budgetResetAt)
        XCTAssertTrue(result.limitSources.contains("/key/info: $10.00 of $100.00"))
    }

    func testKeyBudgetWindowsStoredAsJSONStringAreDecoded() async throws {
        let result = try await fetch(scenario: "key-window-string")

        XCTAssertEqual(result.endpoint, "/key/info budget_limits[1d]")
        XCTAssertEqual(result.info.maxBudget, 5)
    }

    func testKeyBudgetWindowWithoutUsageIsSkipped() async throws {
        let result = try await fetch(scenario: "key-window-no-usage")

        XCTAssertEqual(result.endpoint, "/key/info")
        XCTAssertEqual(result.info.maxBudget, 100)
    }

    func testPercentageModeWithoutLimitShowsSpend() {
        let info = BudgetInfo(
            userId: "fixture-user", spend: 12.5, maxBudget: nil, budgetDuration: nil, budgetResetAt: nil, userEmail: nil
        )

        XCTAssertEqual(info.usageText(.percentage), "$12.50")
        XCTAssertEqual(info.usageText(.dollar), "$12.50")
    }

    func testPercentageModeWithLimitShowsPercentage() {
        let info = BudgetInfo(
            userId: "fixture-user", spend: 12.5, maxBudget: 50, budgetDuration: nil, budgetResetAt: nil, userEmail: nil
        )

        XCTAssertEqual(info.usageText(.percentage), "25%")
    }

    func testUnavailableTeamEndpointFallsBackToUser() async throws {
        let result = try await fetch(scenario: "team-unavailable")

        XCTAssertEqual(result.endpoint, "/v2/user/info")
        XCTAssertEqual(result.info.spend, 12.5)
    }

    func testFallbackAuthenticationFailureIsNotReportedAsZeroUsage() async {
        do {
            _ = try await fetch(scenario: "user-auth-error")
            XCTFail("An authentication failure must not become a successful zero-spend result")
        } catch APIError.httpError(let code) {
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUsageWithoutLimitOrResetCanLoadDailyActivity() throws {
        let info = try JSONDecoder().decode(
            BudgetInfo.self, from: Data(#"{"user_id":"fixture-user","spend":12.5}"#.utf8)
        )

        XCTAssertFalse(info.hasBudgetLimit)
        XCTAssertNil(info.budgetResetAt)
        XCTAssertTrue(info.canLoadDailyActivity)
        XCTAssertEqual(info.spend, 12.5)
    }

    func testDailyActivityWithoutBudgetConfigurationUsesMockAPI() async throws {
        let api = makeAPI()
        let (activity, _, _) = try await api.fetchDailyActivity(
            baseURL: "https://no-team-budget.invalid", apiKey: "fixture-key", userId: "fixture-user",
            startDate: Date(timeIntervalSince1970: 0), endDate: Date(timeIntervalSince1970: 86_400)
        )

        XCTAssertEqual(activity.count, 1)
        XCTAssertEqual(activity.first?.metrics.spend, 3.25)
    }

    func testMissingUserIDDoesNotAllowDailyActivityFetch() {
        let info = BudgetInfo(
            userId: "", spend: 0, maxBudget: nil, budgetDuration: nil, budgetResetAt: nil, userEmail: nil
        )

        XCTAssertFalse(info.canLoadDailyActivity)
    }

    func testLowestLimitWinsWhenKeyBudgetIsLowerThanUserBudget() async throws {
        let result = try await fetch(scenario: "key-lowest")

        XCTAssertEqual(result.endpoint, "/key/info")
        XCTAssertEqual(result.info.maxBudget, 25)
        XCTAssertEqual(result.info.spend, 7)
        XCTAssertEqual(result.info.userId, "fixture-user")
        XCTAssertTrue(result.limitSources.contains("/key/info: $7.00 of $25.00"))
        XCTAssertTrue(result.limitSources.contains("/v2/user/info: $12.50 of $100.00"))
    }

    func testLowestLimitWinsWhenUserBudgetIsLowerThanKeyBudget() async throws {
        let result = try await fetch(scenario: "user-lowest")

        XCTAssertEqual(result.endpoint, "/v2/user/info")
        XCTAssertEqual(result.info.maxBudget, 25)
        XCTAssertEqual(result.info.spend, 12.5)
    }

    func testTeamBudgetIsUsedWhenItIsTheLowestLimit() async throws {
        let result = try await fetch(scenario: "team-lowest")

        XCTAssertEqual(result.endpoint, "/team/info")
        XCTAssertEqual(result.info.maxBudget, 25)
        XCTAssertEqual(result.info.spend, 9)
        XCTAssertEqual(result.info.userId, "fixture-user")
    }

    func testTeamMemberBudgetWinsOverHigherTeamAndUserBudgets() async throws {
        let result = try await fetch(scenario: "member-lowest")

        XCTAssertEqual(result.endpoint, "/team/team-fixture/members/me")
        XCTAssertEqual(result.info.maxBudget, 25)
    }

    func testEqualLimitsPreferTheMoreSpecificSource() async throws {
        let result = try await fetch(scenario: "tie")

        XCTAssertEqual(result.endpoint, "/key/info")
        XCTAssertEqual(result.info.maxBudget, 25)
    }

    func testKeyBudgetIsUsedWithoutTeam() async throws {
        let result = try await fetch(scenario: "key-no-team")

        XCTAssertEqual(result.endpoint, "/key/info")
        XCTAssertEqual(result.info.maxBudget, 25)
        XCTAssertNil(result.keyInfo.teamId)
    }

    func testKeyBudgetSurvivesUserEndpointFailure() async throws {
        let result = try await fetch(scenario: "key-user-error")

        XCTAssertEqual(result.endpoint, "/key/info")
        XCTAssertEqual(result.info.maxBudget, 25)
    }

    func testMalformedKeyBudgetFieldsDoNotHideTeamAttachment() async throws {
        let result = try await fetch(scenario: "key-malformed")

        XCTAssertEqual(result.keyInfo.teamId, "team-fixture")
        XCTAssertEqual(result.endpoint, "/v2/user/info")
        XCTAssertNil(result.info.maxBudget)
    }

    func testTeamInfoWithoutTeamDetailsIsSkipped() async throws {
        let result = try await fetch(scenario: "team-info-missing")

        XCTAssertEqual(result.endpoint, "/v2/user/info")
        XCTAssertNil(result.info.maxBudget)
        XCTAssertFalse(result.limitSources.contains("/team/info"))
    }

    func testNoLimitAnywhereReportsLimitSourcesAsEmpty() async throws {
        let result = try await fetch(scenario: "no-team-budget")

        XCTAssertEqual(result.limitSources, "")
    }

    private func fetch(scenario: String) async throws -> BudgetFetchResult {
        try await makeAPI().fetchResolvedBudgetInfo(
            baseURL: "https://\(scenario).invalid", apiKey: "fixture-key"
        )
    }

    private func makeAPI() -> APIService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BudgetFixtureURLProtocol.self]
        return APIService(configuration: configuration)
    }
}

private final class BudgetFixtureURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (status, body) = fixture(url: url)
        guard let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static let defaults: [String: (Int, String)] = [
        "/key/info": (200, #"{"info":{"team_id":"team-fixture"}}"#),
        "/team/team-fixture/members/me": (200, #"{"user_id":"fixture-user","spend":0,"litellm_budget_table":null}"#),
        "/team/info": (200, #"{"team_id":"team-fixture","team_info":{"spend":9,"max_budget":null}}"#),
        "/v2/user/info": (200, #"{"user_id":"fixture-user","spend":12.5,"max_budget":null}"#),
        "/user/daily/activity": (200, #"{"results":[{"date":"1970-01-01","metrics":{"spend":3.25}}]}"#)
    ]

    private static let member = "/team/team-fixture/members/me"

    /// Per-scenario overrides, keyed by host and then by path.
    private static let overrides: [String: [String: (Int, String)]] = [
        "team-unavailable.invalid": [member: (404, "{}")],
        "team-budget.invalid": [
            member: (200, #"{"user_id":"fixture-user","spend":4,"litellm_budget_table":{"max_budget":50}}"#)
        ],
        "user-auth-error.invalid": ["/v2/user/info": (401, "{}")],
        "user-budget.invalid": [
            "/v2/user/info": (200, #"{"user_id":"fixture-user","spend":12.5,"max_budget":100}"#)
        ],
        "personal-user-budget.invalid": [
            "/key/info": (200, #"{"info":{"user_id":"fixture-user"}}"#),
            "/v2/user/info": (200, #"{"user_id":"fixture-user","spend":12.5,"max_budget":100}"#)
        ],
        "remaining.invalid": [
            "/key/info": (200, #"{"info":{"team_id":"team-fixture","spend":0,"max_budget":50}}"#),
            member: (200, #"{"user_id":"fixture-user","spend":99,"litellm_budget_table":{"max_budget":100}}"#)
        ],
        "member-default.invalid": [
            member: (200, #"{"user_id":"fixture-user","spend":6,"litellm_budget_table":null}"#),
            "/team/info": (200, #"""
                {"team_id":"team-fixture","team_info":{"spend":9,"max_budget":null,
                "team_member_budget_table":{"max_budget":30,"budget_duration":"1mo"}}}
                """#)
        ],
        "member-default-zero.invalid": [
            member: (200, #"{"user_id":"fixture-user","spend":6,"litellm_budget_table":null}"#),
            "/team/info": (200, #"""
                {"team_id":"team-fixture","team_info":{"spend":9,"team_member_budget_table":{"max_budget":0}}}
                """#)
        ],
        "key-window.invalid": [
            "/key/info": (200, #"""
                {"info":{"user_id":"fixture-user","spend":10,"max_budget":100,
                "budget_limits":[{"budget_duration":"1d","max_budget":5,"reset_at":"2026-11-19T00:00:00Z"}],
                "budget_limits_usage":{"1d":{"current_spend":4}}}}
                """#)
        ],
        "key-window-string.invalid": [
            "/key/info": (200, #"""
                {"info":{"user_id":"fixture-user","spend":10,"max_budget":100,
                "budget_limits":"[{\"budget_duration\":\"1d\",\"max_budget\":5}]",
                "budget_limits_usage":{"1d":{"current_spend":4}}}}
                """#)
        ],
        "key-window-no-usage.invalid": [
            "/key/info": (200, #"""
                {"info":{"user_id":"fixture-user","spend":10,"max_budget":100,
                "budget_limits":[{"budget_duration":"1d","max_budget":5}]}}
                """#)
        ],
        "key-lowest.invalid": [
            "/key/info": (200, #"{"info":{"user_id":"fixture-user","spend":7,"max_budget":25}}"#),
            "/v2/user/info": (200, #"{"user_id":"fixture-user","spend":12.5,"max_budget":100}"#)
        ],
        "user-lowest.invalid": [
            "/key/info": (200, #"{"info":{"spend":3,"max_budget":100}}"#),
            "/v2/user/info": (200, #"{"user_id":"fixture-user","spend":12.5,"max_budget":25}"#)
        ],
        "team-lowest.invalid": [
            "/team/info": (200, #"{"team_id":"team-fixture","team_info":{"spend":9,"max_budget":25}}"#),
            "/v2/user/info": (200, #"{"user_id":"fixture-user","spend":12.5,"max_budget":100}"#)
        ],
        "member-lowest.invalid": [
            member: (200, #"{"user_id":"fixture-user","spend":1,"litellm_budget_table":{"max_budget":25}}"#),
            "/team/info": (200, #"{"team_id":"team-fixture","team_info":{"spend":9,"max_budget":80}}"#),
            "/v2/user/info": (200, #"{"user_id":"fixture-user","spend":12.5,"max_budget":60}"#)
        ],
        "tie.invalid": [
            "/key/info": (200, #"{"info":{"team_id":"team-fixture","spend":9,"max_budget":25}}"#),
            "/team/info": (200, #"{"team_id":"team-fixture","team_info":{"spend":9,"max_budget":25}}"#),
            "/v2/user/info": (200, #"{"user_id":"fixture-user","spend":12.5,"max_budget":25}"#)
        ],
        "key-no-team.invalid": [
            "/key/info": (200, #"{"info":{"team_id":null,"spend":2,"max_budget":25}}"#)
        ],
        "key-user-error.invalid": [
            "/key/info": (200, #"{"info":{"spend":2,"max_budget":25}}"#),
            "/v2/user/info": (401, "{}")
        ],
        "team-info-missing.invalid": [
            "/team/info": (200, #"{"team_id":"team-fixture"}"#),
            "/v2/user/info": (200, #"{"user_id":"fixture-user","spend":12.5,"max_budget":100}"#)
        ],
        "key-malformed.invalid": [
            "/key/info": (200, #"{"info":{"team_id":"team-fixture","spend":"n/a","max_budget":"n/a"}}"#),
            "/v2/user/info": (200, #"{"user_id":"fixture-user","spend":12.5,"max_budget":100}"#)
        ]
    ]

    private func fixture(url: URL) -> (Int, String) {
        let host = url.host ?? ""
        return Self.overrides[host]?[url.path] ?? Self.defaults[url.path] ?? (500, "{}")
    }
}
