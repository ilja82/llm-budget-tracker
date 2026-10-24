import Foundation

enum MetricKind: String, CaseIterable, Codable, Identifiable {
    case spend
    case tokens
    case requests

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spend: return "Spend"
        case .tokens: return "Tokens"
        case .requests: return "Requests"
        }
    }
}

enum ModelRange: String, CaseIterable, Codable, Identifiable {
    case thisMonth
    case last28
    case thisWeek
    case lastWeek

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thisMonth: return "This month"
        case .last28: return "Last 28 days"
        case .thisWeek: return "This week"
        case .lastWeek: return "Last week"
        }
    }

    /// UTC date bounds matching the API's daily `yyyy-MM-dd` values; the end is exclusive.
    func dateRange(relativeTo now: Date) -> Range<String>? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 2 // Monday, regardless of the user's locale.
        let today = calendar.startOfDay(for: now)
        let start: Date?
        let end: Date?
        switch self {
        case .thisMonth:
            let interval = calendar.dateInterval(of: .month, for: today)
            start = interval?.start
            end = interval?.end
        case .last28:
            start = calendar.date(byAdding: .day, value: -27, to: today)
            end = calendar.date(byAdding: .day, value: 1, to: today)
        case .thisWeek:
            let interval = calendar.dateInterval(of: .weekOfYear, for: today)
            start = interval?.start
            end = interval?.end
        case .lastWeek:
            let interval = calendar.dateInterval(of: .weekOfYear, for: today)
            end = interval?.start
            start = end.flatMap { calendar.date(byAdding: .day, value: -7, to: $0) }
        }
        guard let start, let end else { return nil }

        func dateString(_ date: Date) -> String {
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return String(
                format: "%04d-%02d-%02d",
                components.year ?? 0, components.month ?? 0, components.day ?? 1
            )
        }
        return dateString(start)..<dateString(end)
    }
}
