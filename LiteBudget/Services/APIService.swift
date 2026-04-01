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

    func fetchBudgetInfo(baseURL: String, apiKey: String) async throws -> BudgetInfo {
        let url = try endpoint(base: baseURL, path: "/v2/user/info")
        let request = authenticatedRequest(url: url, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(BudgetInfo.self, from: data)
    }

    func fetchSpendLogs(
        baseURL: String,
        apiKey: String,
        startDate: Date,
        page: Int = 1
    ) async throws -> [SpendLog] {
        guard var components = URLComponents(string: baseURL + "/spend/logs/v2") else {
            throw APIError.invalidURL
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        components.queryItems = [
            URLQueryItem(name: "start_date", value: fmt.string(from: startDate)),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "100")
        ]
        guard let url = components.url else { throw APIError.invalidURL }
        let request = authenticatedRequest(url: url, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        if let logs = try? decoder.decode([SpendLog].self, from: data) { return logs }
        return try decoder.decode(SpendLogsResponse.self, from: data).data
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