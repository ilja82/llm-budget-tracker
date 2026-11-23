import Foundation

enum DashboardFormat {
    static func dollars(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    static func axisDollars(_ value: Double, maxValue: Double) -> String {
        String(format: maxValue < 10 ? "$%.2f" : "$%.0f", value)
    }

    static func share(_ value: Double, of total: Double) -> String {
        guard total > 0 else { return "–" }
        return String(format: "%.1f%%", value / total * 100)
    }

    static func localDate(_ value: String) -> Date? {
        DashboardStats.date(from: value, calendar: .current)
    }

    static func displayDate(_ value: String) -> String {
        guard let date = localDate(value) else { return value }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }
}
