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

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thisMonth: return "This month"
        case .last28: return "Last 28 days"
        }
    }
}
