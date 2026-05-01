import Foundation

enum ResponseSanitizer {
    private static let redactedKeys: Set<String> = [
        "access_token",
        "api_key",
        "apikey",
        "authorization",
        "email",
        "password",
        "refresh_token",
        "secret",
        "token",
        "user_email"
    ]

    static func sanitize(data: Data) -> String {
        guard !data.isEmpty else { return "" }

        if let json = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(json),
           let sanitizedData = try? JSONSerialization.data(
                withJSONObject: sanitizeJSONObject(json),
                options: [.prettyPrinted, .sortedKeys]
           ),
           let string = String(data: sanitizedData, encoding: .utf8) {
            return string
        }

        let fallback = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
        return sanitizePlainText(fallback)
    }

    static func truncatedForDisplay(_ text: String, maxLength: Int = 4_096) -> String {
        guard text.count > maxLength else { return text }
        let endIndex = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<endIndex]) + "\n...[truncated]"
    }

    private static func sanitizeJSONObject(_ value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            var sanitized: [String: Any] = [:]
            for (key, rawValue) in dictionary {
                let normalizedKey = key.lowercased()
                if redactedKeys.contains(normalizedKey) {
                    sanitized[key] = "[REDACTED]"
                } else {
                    sanitized[key] = sanitizeJSONObject(rawValue)
                }
            }
            return sanitized
        case let array as [Any]:
            return array.map(sanitizeJSONObject)
        default:
            return value
        }
    }

    private static func sanitizePlainText(_ text: String) -> String {
        let emailPattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        let tokenPattern = #"(?i)(authorization|x-litellm-api-key|api[_-]?key|token|secret|password)\s*[:=]\s*[^\s,]+"#
        let emailRedacted = text.replacingOccurrences(
            of: emailPattern,
            with: "[REDACTED_EMAIL]",
            options: [.regularExpression, .caseInsensitive]
        )
        return emailRedacted.replacingOccurrences(
            of: tokenPattern,
            with: "[REDACTED_SECRET]",
            options: .regularExpression
        )
    }
}
