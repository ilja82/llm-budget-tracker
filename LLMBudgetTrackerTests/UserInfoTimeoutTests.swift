import XCTest

final class UserInfoTimeoutTests: XCTestCase {
    func testTeamKeyKeepsTheMemberBudgetWhenUserInfoTimesOut() async throws {
        let result = try await makeAPI().fetchResolvedBudgetInfo(baseURL: "https://team.invalid", apiKey: "fixture-key")

        XCTAssertEqual(result.endpoint, "/team/team-fixture/members/me")
        XCTAssertEqual(result.info.maxBudget, 50)
        XCTAssertEqual(result.info.spend, 4)
        XCTAssertEqual(result.info.userId, "fixture-user")
    }

    func testTeamKeyWithoutAnyLimitStillFailsWhenUserInfoTimesOut() async {
        do {
            _ = try await makeAPI().fetchResolvedBudgetInfo(baseURL: "https://team-no-limit.invalid", apiKey: "fixture-key")
            XCTFail("Without a limit the user spend is needed, so the timeout must fail the refresh")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testKeyWithoutTeamStillFailsWhenUserInfoTimesOut() async {
        do {
            _ = try await makeAPI().fetchResolvedBudgetInfo(baseURL: "https://no-team.invalid", apiKey: "fixture-key")
            XCTFail("The user limit can be the binding one, so the timeout must fail the refresh")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeAPI() -> APIService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UserInfoTimeoutURLProtocol.self]
        return APIService(configuration: configuration)
    }
}

private final class UserInfoTimeoutURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        guard url.path != "/v2/user/info" else {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        guard let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body(host: url.host ?? "", path: url.path).utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func body(host: String, path: String) -> String {
        switch (host, path) {
        case ("no-team.invalid", "/key/info"):
            return #"{"info":{"user_id":"fixture-user","spend":1,"max_budget":25}}"#
        case (_, "/key/info"):
            return #"{"info":{"team_id":"team-fixture","user_id":"fixture-user"}}"#
        case ("team.invalid", "/team/team-fixture/members/me"):
            return #"{"user_id":"fixture-user","spend":4,"litellm_budget_table":{"max_budget":50}}"#
        case (_, "/team/team-fixture/members/me"):
            return #"{"user_id":"fixture-user","spend":0,"litellm_budget_table":null}"#
        case (_, "/team/info"):
            return #"{"team_id":"team-fixture","team_info":{"spend":9,"max_budget":null}}"#
        default:
            return "{}"
        }
    }
}
