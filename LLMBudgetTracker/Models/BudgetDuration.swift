import Foundation

enum BudgetDuration {
    /// Parses a LiteLLM `budget_duration` ("30s", "24h", "30d", "1w", "1mo") into a whole number of days.
    /// Returns nil for indefinite periods so callers can avoid open-ended loops.
    static func days(_ duration: String) -> Int? {
        let s = duration.lowercased()
        if s.contains("indefinite") || s == "none" || s == "never" {
            return nil
        }
        if s == "daily" { return 1 }
        if s == "weekly" { return 7 }
        if s == "monthly" { return 30 }
        if s.hasSuffix("mo"), let num = Int(s.dropLast(2)) { return max(1, num * 30) }
        if s.hasSuffix("w"), let num = Int(s.dropLast()) { return max(1, num * 7) }
        if s.hasSuffix("d"), let num = Int(s.dropLast()) { return max(num, 1) }
        if s.hasSuffix("s"), let num = Int(s.dropLast()) { return max(1, Int(ceil(Double(num) / 86_400.0))) }
        if s.hasSuffix("h"), let num = Int(s.dropLast()) { return max(1, Int(ceil(Double(num) / 24.0))) }
        if s.hasSuffix("m"), let num = Int(s.dropLast()) { return max(1, Int(ceil(Double(num) / 1_440.0))) }
        return 30
    }
}
