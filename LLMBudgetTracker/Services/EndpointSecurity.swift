import Foundation

enum EndpointSecurity {
    private static let allowedLoopbackHosts: Set<String> = [
        "localhost",
        "127.0.0.1",
        "::1"
    ]

    static func normalizedBaseURL(from rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            throw EndpointSecurityError.invalidURL
        }

        guard scheme == "https" || scheme == "http" else {
            throw EndpointSecurityError.invalidURL
        }
        if scheme == "http", !allowedLoopbackHosts.contains(host) {
            throw EndpointSecurityError.insecureRemoteURL
        }

        var normalized = components
        normalized.scheme = scheme
        normalized.host = host
        let normalizedPath = normalized.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        normalized.path = normalizedPath.isEmpty ? "" : "/" + normalizedPath

        guard let url = normalized.url else {
            throw EndpointSecurityError.invalidURL
        }
        return url
    }

    static func normalizedBaseURLString(from rawValue: String) throws -> String {
        try normalizedBaseURL(from: rawValue).absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

enum EndpointSecurityError: LocalizedError {
    case invalidURL
    case insecureRemoteURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid LiteLLM proxy URL."
        case .insecureRemoteURL:
            return "Use HTTPS for remote proxies. HTTP is only allowed for localhost."
        }
    }
}
