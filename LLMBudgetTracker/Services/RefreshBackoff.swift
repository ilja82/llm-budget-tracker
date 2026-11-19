import Foundation

enum RefreshBackoff {
    static let baseSeconds = 30
    static let maxShortSeconds = 300
    static let longDelaySeconds = 3600
    static let longDelayThreshold = 8

    static func delaySeconds(consecutiveFailures: Int) -> Int {
        guard consecutiveFailures <= longDelayThreshold else { return longDelaySeconds }
        let exponent = max(consecutiveFailures - 1, 0)
        let doubled = baseSeconds << min(exponent, 8)
        return min(doubled, maxShortSeconds)
    }
}
