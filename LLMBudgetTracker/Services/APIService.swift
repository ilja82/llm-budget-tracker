import Foundation

actor APIService {
    private enum Constants {
        static let apiKeyHeaderField: String = "x-litellm-api-key"
        static let requestTimeoutSeconds: TimeInterval = 15
        static let defaultPage: String = "1"
        static let defaultPageSize: String = "32"
    }

    // DateFormatter is not thread-safe: keep as actor-isolated instance property
    private let dailyFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // ISO8601DateFormatter is documented as thread-safe; used from non-isolated
    // dateDecodingStrategy closure so marked nonisolated(unsafe)
    private nonisolated(unsafe) static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private nonisolated(unsafe) static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        session = URLSession.shared
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            return try Self.parseDate(string, container: container)
        }
    }

    // MARK: - Public

    func fetchBudgetInfo(baseURL: String, apiKey: String) async throws -> (BudgetInfo, String, Int?) {
        let url = try endpoint(base: baseURL, path: "/v2/user/info")
        let request = authenticatedRequest(url: url, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        try validate(response)
        let rawJSON = String(data: data, encoding: .utf8) ?? ""
        return (try decoder.decode(BudgetInfo.self, from: data), rawJSON, statusCode)
    }

    func fetchDailyActivity(
        baseURL: String,
        apiKey: String,
        userId: String,
        startDate: Date,
        endDate: Date
    ) async throws -> ([DailySpendData], String, Int?) {
        guard var components = URLComponents(string: baseURL + "/user/daily/activity") else {
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
        guard let url = components.url else { throw APIError.invalidURL }
        let request = authenticatedRequest(url: url, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        try validate(response)
        let rawJSON = String(data: data, encoding: .utf8) ?? ""
        let daily = try decoder.decode(DailyActivityResponse.self, from: data)
        return (daily.results, rawJSON, statusCode)
    }

    // MARK: - Helpers

    private func endpoint(base: String, path: String) throws -> URL {
        guard let url = URL(string: base.trimmingCharacters(in: .init(charactersIn: "/")) + path) else {
            throw APIError.invalidURL
        }
        return url
    }

    private func authenticatedRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: Constants.apiKeyHeaderField)
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