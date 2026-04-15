import Foundation

enum AppLoadState: Equatable {
    case notConfigured
    case loading
    case refreshing
    case loaded
    case authError
    case networkError
    case invalidData
    case noBudget
    case unknownError
}

enum ConnectionTestResult {
    case connected
    case invalidURL
    case authFailed
    case serverUnreachable
    case testFailed

    var message: String {
        switch self {
        case .connected: return "Connected"
        case .invalidURL: return "Invalid URL"
        case .authFailed: return "Authentication failed"
        case .serverUnreachable: return "Server unreachable"
        case .testFailed: return "Connection test failed"
        }
    }

    var isSuccess: Bool { self == .connected }
}
