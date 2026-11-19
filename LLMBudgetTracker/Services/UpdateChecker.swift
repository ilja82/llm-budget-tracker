import Foundation

protocol UpdateChecking: Sendable {
    func fetchLatestRelease() async throws -> ReleaseInfo
}

enum UpdateCheckError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case invalidRelease
}

struct UpdateChecker: UpdateChecking {
    static let latestReleaseURLString = "https://api.github.com/repos/ilja82/llm-budget-tracker/releases/latest"
    static let requestTimeout: TimeInterval = 30

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private let session: URLSession
    private let userAgent: String

    init(version: String = Self.appVersion, configuration: URLSessionConfiguration = .ephemeral) {
        configuration.timeoutIntervalForRequest = Self.requestTimeout
        configuration.timeoutIntervalForResource = Self.requestTimeout
        configuration.waitsForConnectivity = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
        userAgent = "LLMBudgetTracker/\(version)"
    }

    func makeRequest() throws -> URLRequest {
        guard let url = URL(string: Self.latestReleaseURLString) else { throw UpdateCheckError.invalidURL }
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Self.requestTimeout
        )
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    func fetchLatestRelease() async throws -> ReleaseInfo {
        let (data, response) = try await session.data(for: makeRequest())
        guard let http = response as? HTTPURLResponse else { throw UpdateCheckError.invalidResponse }
        guard http.statusCode == 200 else { throw UpdateCheckError.httpStatus(http.statusCode) }
        return try Self.decodeRelease(from: data)
    }

    static func decodeRelease(from data: Data) throws -> ReleaseInfo {
        let payload = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let release = UpdatePolicy.release(tagName: payload.tagName, publishedAt: payload.publishedAt) else {
            throw UpdateCheckError.invalidRelease
        }
        return release
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let publishedAt: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case publishedAt = "published_at"
    }
}
