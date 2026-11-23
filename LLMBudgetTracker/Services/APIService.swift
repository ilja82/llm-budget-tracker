import Foundation

actor APIService {
    private enum Constants {
        static let apiKeyHeaderField: String = "x-litellm-api-key"
        static let requestTimeoutSeconds: TimeInterval = 15
        static let resourceTimeoutSeconds: TimeInterval = 30
        static let dailyActivityPageSize = 1000
        static let dailyActivityMaxPages = 20
    }

    // DateFormatter is not thread-safe: keep as actor-isolated instance property
    private let dailyFmt = DayKeyFormatter.make()

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

    // Reads zone-less LiteLLM dates as UTC. It ignores offsets, so parseDate tries it last.
    nonisolated(unsafe) private static let iso8601WithoutTimeZone: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let now: @Sendable () -> Date

    init(configuration: URLSessionConfiguration = .ephemeral, now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
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

    /// Resolves the budget of the caller for the calling key. Personal levels are the key
    /// (GET /key/info, including its `budget_limits` windows), the team member
    /// (GET /team/{id}/members/me, or the team's default member budget) and, for keys without
    /// a team, the user (GET /v2/user/info). The personal level with the least remaining budget
    /// is reported. The shared team budget (GET /team/info) is reported only without a personal
    /// limit; otherwise it is returned as `teamBudget` when less of it remains.
    /// Without any limit, the user-level spend is reported.
    func fetchResolvedBudgetInfo(baseURL: String, apiKey: String) async throws -> BudgetFetchResult {
        let keyInfo = try await fetchKeyInfo(baseURL: baseURL, apiKey: apiKey)
        let teamId = keyInfo.teamId.flatMap { $0.isEmpty ? nil : $0 }
        var personal = keyCandidates(keyInfo)
        var team: BudgetCandidate?
        var memberSpend: BudgetCandidate?
        var unavailable: [String] = []
        if let teamId {
            let sources = try await teamCandidates(baseURL: baseURL, apiKey: apiKey, teamId: teamId)
            personal += [sources.member].compactMap { $0 }
            team = sources.team
            memberSpend = sources.memberSpend
            unavailable = sources.unavailable
        }

        let userResult = try await userBudgetResult(
            baseURL: baseURL, apiKey: apiKey, toleratesTransportErrors: teamId != nil
        )
        let userCandidate = try? userResult.get()
        if teamId == nil, let userCandidate, userCandidate.info.hasBudgetLimit {
            personal.append(userCandidate)
        }

        if teamId != nil, let failure = userResult.failureText {
            unavailable.append("/v2/user/info: unavailable (\(failure))")
        }
        let summary = ((personal + [team].compactMap { $0 }).map(\.summary) + unavailable).joined(separator: ", ")
        let mostLimited = personal.min(by: { $0.info.remainingBudget < $1.info.remainingBudget })
        if let chosen = mostLimited ?? team {
            let userId = [chosen.info.userId, userCandidate?.info.userId, keyInfo.details?.userId]
                .compactMap { $0 }.first { !$0.isEmpty } ?? ""
            let teamBudget = team.map(\.info).flatMap {
                $0.remainingBudget < chosen.info.remainingBudget ? $0 : nil
            }
            return BudgetFetchResult(
                info: chosen.info.withUserId(userId), rawJSON: chosen.rawJSON, statusCode: chosen.statusCode,
                endpoint: chosen.endpoint, keyInfo: keyInfo, limitSources: summary, teamBudget: teamBudget
            )
        }
        let user: BudgetCandidate
        switch userResult {
        case .success(let candidate):
            user = candidate
        case .failure(let error):
            guard error is URLError, let memberSpend else { throw error }
            user = memberSpend
        }
        return BudgetFetchResult(
            info: teamId == nil ? user.info : user.info.withoutBudgetLimit(),
            rawJSON: user.rawJSON, statusCode: user.statusCode,
            endpoint: user.endpoint, keyInfo: keyInfo, limitSources: summary, teamBudget: nil
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

    /// Fetches the team details with the team budget and the default team-member budget.
    /// Source: GET /team/info?team_id=…
    func fetchTeamInfo(
        baseURL: String,
        apiKey: String,
        teamId: String
    // swiftlint:disable:next large_tuple
    ) async throws -> (TeamInfoDetails, String, Int?) {
        let url = try endpoint(base: baseURL, path: "/team/info")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "team_id", value: teamId),
            URLQueryItem(name: "include_members", value: "false")
        ]
        guard let requestURL = components.url else { throw APIError.invalidURL }
        let request = authenticatedRequest(url: requestURL, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        try validate(response)
        let rawJSON = sanitizedLogBody(from: data)
        let team = try decoder.decode(TeamInfoResponse.self, from: data)
        return (team.teamInfo, rawJSON, statusCode)
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
        return (member.toBudgetInfo(now: now()), rawJSON, statusCode)
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
        var results: [DailySpendData] = []
        var bodies: [String] = []
        var statusCode: Int?
        for page in 1...Constants.dailyActivityMaxPages {
            components.queryItems = [
                URLQueryItem(name: "user_id", value: userId),
                URLQueryItem(name: "start_date", value: fmt.string(from: startDate)),
                URLQueryItem(name: "end_date", value: fmt.string(from: endDate)),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "page_size", value: String(Constants.dailyActivityPageSize))
            ]
            guard let requestURL = components.url else { throw APIError.invalidURL }
            let request = authenticatedRequest(url: requestURL, apiKey: apiKey)
            let (data, response) = try await session.data(for: request)
            statusCode = (response as? HTTPURLResponse)?.statusCode
            try validate(response)
            bodies.append(sanitizedLogBody(from: data))
            let daily = try decoder.decode(DailyActivityResponse.self, from: data)
            results += daily.results
            if !daily.hasMore { break }
        }
        return (DailySpendData.combinedByDate(results), bodies.joined(separator: "\n"), statusCode)
    }

    // MARK: - Helpers

    private func keyCandidates(_ keyInfo: KeyInfoFetch) -> [BudgetCandidate] {
        guard let details = keyInfo.details else { return [] }
        let info = details.toBudgetInfo(now: now())
        let limits = (info.hasBudgetLimit ? [("/key/info", info)] : [])
            + details.windowBudgets().map { ("/key/info budget_limits[\($0.budgetDuration ?? "")]", $0) }
        return limits.map { endpoint, info in
            BudgetCandidate(endpoint: endpoint, info: info, rawJSON: keyInfo.rawJSON, statusCode: keyInfo.statusCode)
        }
    }

    private func teamCandidates(
        baseURL: String, apiKey: String, teamId: String
    ) async throws -> TeamSources {
        let memberEndpoint = "/team/\(teamId)/members/me"
        let memberResult = try await bestEffort {
            try await fetchTeamMemberBudget(baseURL: baseURL, apiKey: apiKey, teamId: teamId)
        }
        let teamResult = try await bestEffort {
            try await fetchTeamInfo(baseURL: baseURL, apiKey: apiKey, teamId: teamId)
        }
        let unavailable = [(memberEndpoint, memberResult.failureText), ("/team/info", teamResult.failureText)]
            .compactMap { endpoint, failure in failure.map { "\(endpoint): unavailable (\($0))" } }
        let member = try? memberResult.get()
        let team = try? teamResult.get()
        var memberCandidate: BudgetCandidate?
        if let (info, json, status) = member,
           let memberInfo = Self.effectiveMemberBudget(member: info, team: team?.0) {
            memberCandidate = BudgetCandidate(
                endpoint: memberEndpoint, info: memberInfo, rawJSON: json, statusCode: status
            )
        }
        var teamCandidate: BudgetCandidate?
        if let (details, json, status) = team, details.toBudgetInfo().hasBudgetLimit {
            teamCandidate = BudgetCandidate(
                endpoint: "/team/info", info: details.toBudgetInfo(), rawJSON: json, statusCode: status
            )
        }
        let memberSpend = member.map { info, json, status in
            BudgetCandidate(
                endpoint: memberEndpoint, info: info.withoutBudgetLimit(), rawJSON: json, statusCode: status
            )
        }
        return TeamSources(
            member: memberCandidate, memberSpend: memberSpend, team: teamCandidate, unavailable: unavailable
        )
    }

    /// The member's own limit, else the team's default member budget plus the member's active
    /// temporary increase; nil without either.
    private static func effectiveMemberBudget(member: BudgetInfo, team: TeamInfoDetails?) -> BudgetInfo? {
        if member.hasBudgetLimit { return member }
        guard let defaultBudget = team?.teamMemberBudgetTable,
              let maxBudget = defaultBudget.maxBudget, maxBudget > 0 else { return nil }
        return BudgetInfo(
            userId: member.userId,
            spend: member.spend,
            maxBudget: maxBudget + (member.temporaryIncrease?.amount ?? 0),
            budgetDuration: defaultBudget.budgetDuration,
            budgetResetAt: defaultBudget.budgetResetAt,
            userEmail: member.userEmail,
            temporaryIncrease: member.temporaryIncrease
        )
    }

    /// For team keys the user level is no budget candidate, so a timeout there must not fail the refresh.
    private func userBudgetResult(
        baseURL: String, apiKey: String, toleratesTransportErrors: Bool
    ) async throws -> Result<BudgetCandidate, Error> {
        do {
            let (info, json, status) = try await fetchBudgetInfo(baseURL: baseURL, apiKey: apiKey)
            return .success(BudgetCandidate(endpoint: "/v2/user/info", info: info, rawJSON: json, statusCode: status))
        } catch let error as APIError {
            return .failure(error)
        } catch let error as DecodingError {
            return .failure(error)
        } catch let error as URLError where toleratesTransportErrors && error.code != .cancelled {
            return .failure(error)
        }
    }

    /// Runs a team budget source lookup. HTTP, decoding and transport failures mean "source unavailable"
    /// and yield a failure; cancellation propagates.
    private func bestEffort<T>(_ operation: () async throws -> T) async throws -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch let error as APIError {
            return .failure(error)
        } catch let error as DecodingError {
            return .failure(error)
        } catch let error as URLError where error.code != .cancelled {
            return .failure(error)
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
        if let date = iso8601WithoutTimeZone.date(from: string) { return date }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(string)")
    }

    private func sanitizedLogBody(from data: Data) -> String {
        ResponseSanitizer.sanitize(data: data)
    }
}

private extension Result where Failure == Error {
    /// A short reason for the request log, or nil on success.
    var failureText: String? {
        guard case .failure(let error) = self else { return nil }
        if let apiError = error as? APIError { return apiError.errorDescription }
        if let urlError = error as? URLError { return urlError.localizedDescription }
        return "invalid response"
    }
}

/// The team member and team budgets of a team key, the member spend without a limit, and a log entry for each
/// source that failed.
private struct TeamSources {
    let member: BudgetCandidate?
    let memberSpend: BudgetCandidate?
    let team: BudgetCandidate?
    let unavailable: [String]
}

/// A budget source that has a limit configured.
private struct BudgetCandidate {
    let endpoint: String
    let info: BudgetInfo
    let rawJSON: String
    let statusCode: Int?

    var summary: String {
        "\(endpoint): " + String(format: "$%.2f of $%.2f", info.spend, info.maxBudget ?? 0)
    }
}

/// Resolved budget plus the endpoint it was read from (for request logging).
/// `limitSources` lists every limit that was found, e.g. "/key/info: $7.00 of $25.00, /team/info: $9.00 of $80.00".
/// `teamBudget` is the shared team budget when it has less remaining than `info`; LiteLLM also blocks on it.
struct BudgetFetchResult: Sendable {
    let info: BudgetInfo
    let rawJSON: String
    let statusCode: Int?
    let endpoint: String
    let keyInfo: KeyInfoFetch
    let limitSources: String
    let teamBudget: BudgetInfo?
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
