import Foundation

actor APIService {
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
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "start_date", value: fmt.string(from: startDate)),
            URLQueryItem(name: "end_date", value: fmt.string(from: endDate)),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "page_size", value: "32")
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
        request.setValue(apiKey, forHTTPHeaderField: "x-litellm-api-key")
        request.timeoutInterval = 15
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
    }

    private static func parseDate(_ string: String, container: SingleValueDecodingContainer) throws -> Date {
        let formatters: [ISO8601DateFormatter] = [
            { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }(),
            { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
        ]
        for formatter in formatters {
            if let date = formatter.date(from: string) { return date }
        }
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