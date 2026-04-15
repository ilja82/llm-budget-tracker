import Foundation

enum DiagnosticLoggingMode {
    case disabled
    case full
}

struct CachedActivityEnvelope: Codable {
    static let currentVersion = 1
    let version: Int
    let items: [DailySpendData]
}
