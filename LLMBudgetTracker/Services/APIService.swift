import Foundation

actor APIService {
    private enum Constants {
        static let apiKeyHeaderField: String = "x-litellm-api-key"
        static let requestTimeoutSeconds: TimeInterval = 15
        static let resourceTimeoutSeconds: TimeInterval = 30
        static let defaultPage: String = "1"
        static let defaultPageSize: String = "32"
    }

    // DateFormatter is not thread-safe: keep as actor-isolated instance property
    private let dailyFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // ISO8601DateFormatter is documented as thread-safe; used from non-isolated
    // dateDecodingStrategy closure so marked nonisolated(unsafe)
    nonisolated(unsafe) private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.timeoutIntervalForRequest = Constants.requestTimeoutSeconds
        configuration.timeoutIntervalForResource = Constants.resourceTimeoutSeconds
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            return try Self.parseDate(string, container: container)
        }
    }

    // MARK: - Public

    // swiftlint:disable:next large_tuple
    func fetchBudgetInfo(baseURL: String, apiKey: String) async throws -> (BudgetInfo, String, Int?) {
        let url = try endpoint(base: baseURL, path: "/v2/user/info")
        let request = authenticatedRequest(url: url, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        try validate(response)
        let rawJSON = sanitizedLogBody(from: data)
        return (try decoder.decode(BudgetInfo.self, from: data), rawJSON, statusCode)
    }

    /// Resolves the effective budget for the calling key. LiteLLM can enforce limits on
    /// several levels, so every available source is queried and the lowest limit wins
    /// (spend, reset date and duration come from that same source):
    /// the key itself (GET /key/info), the team-member row (GET /team/{id}/members/me),
    /// the team (GET /team/info) and the user (GET /v2/user/info).
    /// Sources that are unavailable or have no limit are skipped; if none has a limit,
    /// the user-level usage is returned without a limit.
    func fetchResolvedBudgetInfo(baseURL: String, apiKey: String) async throws -> BudgetFetchResult {
        let keyInfo = try await fetchKeyInfo(baseURL: baseURL, apiKey: apiKey)
        var candidates: [BudgetCandidate] = []

        if let details = keyInfo.details {
            let info = details.toBudgetInfo()
            if info.hasBudgetLimit {
                candidates.append(BudgetCandidate(
                    endpoint: "/key/info", info: info, rawJSON: keyInfo.rawJSON, statusCode: keyInfo.statusCode
                ))
            }
        }

        if let teamId = keyInfo.teamId, !teamId.isEmpty {
            // A membership without a budget can be a synthetic zero-spend row, so it only
            // counts as a candidate when it carries a limit.
            if let (info, json, status) = try await bestEffort({
                try await fetchTeamMemberBudget(baseURL: baseURL, apiKey: apiKey, teamId: teamId)
            }), info.hasBudgetLimit {
                candidates.append(BudgetCandidate(
                    endpoint: "/team/\(teamId)/members/me", info: info, rawJSON: json, statusCode: status
                ))
            }
            if let (info, json, status) = try await bestEffort({
                try await fetchTeamBudget(baseURL: baseURL, apiKey: apiKey, teamId: teamId)
            }), info.hasBudgetLimit {
                candidates.append(BudgetCandidate(
                    endpoint: "/team/info", info: info, rawJSON: json, statusCode: status
                ))
            }
        }

        // Transport errors (offline) propagate; HTTP and decoding failures only mean that
        // this source is unavailable.
        let userResult: Result<BudgetCandidate, Error>
        do {
            let (info, json, status) = try await fetchBudgetInfo(baseURL: baseURL, apiKey: apiKey)
            userResult = .success(
                BudgetCandidate(endpoint: "/v2/user/info", info: info, rawJSON: json, statusCode: status)
            )
        } catch let error as APIError {
            userResult = .failure(error)
        } catch let error as DecodingError {
            userResult = .failure(error)
        }
        let userCandidate = try? userResult.get()
        if let userCandidate, userCandidate.info.hasBudgetLimit {
            candidates.append(userCandidate)
        }

        let summary = candidates
            .map { "\($0.endpoint): \(String(format: "$%.2f", $0.info.maxBudget ?? 0))" }
            .joined(separator: ", ")

        // min(by:) keeps the first of equal limits, so the more specific source wins ties.
        if let chosen = candidates.min(by: { ($0.info.maxBudget ?? .infinity) < ($1.info.maxBudget ?? .infinity) }) {
            let userId = [chosen.info.userId, userCandidate?.info.userId, keyInfo.details?.userId]
                .compactMap { $0 }.first { !$0.isEmpty } ?? ""
            return BudgetFetchResult(
                info: chosen.info.withUserId(userId), rawJSON: chosen.rawJSON, statusCode: chosen.statusCode,
                endpoint: chosen.endpoint, keyInfo: keyInfo, limitSources: summary
            )
        }
        // No limit anywhere: report user-level usage, or surface its genuine failure
        // (e.g. a bad key) instead of a misleading empty result.
        let user = try userResult.get()
        return BudgetFetchResult(
            info: user.info, rawJSON: user.rawJSON, statusCode: user.statusCode,
            endpoint: user.endpoint, keyInfo: keyInfo, limitSources: summary
        )
    }

    /// Fetches the calling key's own info to detect team attachment and the key-level
    /// budget, plus the raw body + status for the request log. Best-effort: a non-2xx or
    /// undecodable /key/info yields no details ("no team, no key limit") so the caller
    /// falls through to the other sources instead of failing the whole refresh. Only
    /// transport errors (offline) propagate.
    func fetchKeyInfo(baseURL: String, apiKey: String) async throws -> KeyInfoFetch {
        let url = try endpoint(base: baseURL, path: "/key/info")
        let request = authenticatedRequest(url: url, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        let details: KeyInfoDetails? = {
            if let code = statusCode, !(200..<300).contains(code) { return nil }
            return (try? decoder.decode(KeyInfoResponse.self, from: data))?.info
        }()
        return KeyInfoFetch(details: details, rawJSON: sanitizedLogBody(from: data), statusCode: statusCode)
    }

    /// Fetches the team-level budget. Source: GET /team/info?team_id=…
    func fetchTeamBudget(
        baseURL: String,
        apiKey: String,
        teamId: String
    // swiftlint:disable:next large_tuple
    ) async throws -> (BudgetInfo, String, Int?) {
        let url = try endpoint(base: baseURL, path: "/team/info")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "team_id", value: teamId)]
        guard let requestURL = components.url else { throw APIError.invalidURL }
        let request = authenticatedRequest(url: requestURL, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        try validate(response)
        let rawJSON = sanitizedLogBody(from: data)
        let team = try decoder.decode(TeamInfoResponse.self, from: data)
        return (team.teamInfo.toBudgetInfo(), rawJSON, statusCode)
    }

    /// Fetches the caller's own per-team-member budget row (spend + max budget),
    /// mapped onto BudgetInfo. Source: GET /team/{team_id}/members/me.
    func fetchTeamMemberBudget(
        baseURL: String,
        apiKey: String,
        teamId: String
    // swiftlint:disable:next large_tuple
    ) async throws -> (BudgetInfo, String, Int?) {
        let url = try endpoint(base: baseURL, path: "/team/\(teamId)/members/me")
        let request = authenticatedRequest(url: url, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        try validate(response)
        let rawJSON = sanitizedLogBody(from: data)
        let member = try decoder.decode(TeamMemberInfoResponse.self, from: data)
        return (member.toBudgetInfo(), rawJSON, statusCode)
    }

    func fetchDailyActivity(
        baseURL: String,
        apiKey: String,
        userId: String,
        startDate: Date,
        endDate: Date
    // swiftlint:disable:next large_tuple
    ) async throws -> ([DailySpendData], String, Int?) {
        let url = try endpoint(base: baseURL, path: "/user/daily/activity")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        let fmt = dailyFmt
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "start_date", value: fmt.string(from: startDate)),
            URLQueryItem(name: "end_date", value: fmt.string(from: endDate)),
            URLQueryItem(name: "page", value: Constants.defaultPage),
            URLQueryItem(name: "page_size", value: Constants.defaultPageSize)
        ]
        guard let requestURL = components.url else { throw APIError.invalidURL }
        let request = authenticatedRequest(url: requestURL, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        try validate(response)
        let rawJSON = sanitizedLogBody(from: data)
        let daily = try decoder.decode(DailyActivityResponse.self, from: data)
        return (daily.results, rawJSON, statusCode)
    }

    // MARK: - Helpers

    /// Runs a budget source lookup. HTTP and decoding failures mean "source unavailable"
    /// and yield nil; transport errors and cancellation propagate.
    private func bestEffort<T>(_ operation: () async throws -> T) async throws -> T? {
        do {
            return try await operation()
        } catch is APIError {
            return nil
        } catch is DecodingError {
            return nil
        }
    }

    private func endpoint(base: String, path: String) throws -> URL {
        let baseURL = try EndpointSecurity.normalizedBaseURL(from: base)
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        let sanitizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + ([basePath, sanitizedPath].filter { !$0.isEmpty }).joined(separator: "/")
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }

    private func authenticatedRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: Constants.apiKeyHeaderField)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.requestTimeoutSeconds
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
    }

    private static func parseDate(_ string: String, container: SingleValueDecodingContainer) throws -> Date {
        if let date = iso8601WithFractional.date(from: string) { return date }
        if let date = iso8601Plain.date(from: string) { return date }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(string)")
    }

    private func sanitizedLogBody(from data: Data) -> String {
        ResponseSanitizer.sanitize(data: data)
    }
}

/// A budget source that has a limit configured.
private struct BudgetCandidate {
    let endpoint: String
    let info: BudgetInfo
    let rawJSON: String
    let statusCode: Int?
}

/// Resolved budget plus the endpoint it was read from (for request logging).
/// `limitSources` lists every limit that was found, e.g. "/key/info: $25.00, /v2/user/info: $100.00".
struct BudgetFetchResult: Sendable {
    let info: BudgetInfo
    let rawJSON: String
    let statusCode: Int?
    let endpoint: String
    let keyInfo: KeyInfoFetch
    let limitSources: String
}

/// The /key/info exchange: key details (team attachment, key budget) plus raw body + status
/// for the request log.
struct KeyInfoFetch: Sendable {
    let details: KeyInfoDetails?
    let rawJSON: String
    let statusCode: Int?

    var teamId: String? { details?.teamId }
}

enum APIError: LocalizedError {
    case invalidURL
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid endpoint URL"
        case .httpError(let code): return "Server returned HTTP \(code)"
        }
    }
}
