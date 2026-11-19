import Foundation

struct SpendPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let amount: Double
}

struct DailySpendHoverValue: Equatable {
    let day: Date
    let amount: Double
}

enum DailySpendHover {
    static func nearestPoint(to date: Date, in points: [SpendPoint]) -> SpendPoint? {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return points.first { calendar.startOfDay(for: $0.date) == day }
    }

    static func value(at date: Date, in points: [SpendPoint]) -> DailySpendHoverValue? {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        if let point = nearestPoint(to: date, in: points) {
            return DailySpendHoverValue(day: day, amount: point.amount)
        }
        let days = points.map { calendar.startOfDay(for: $0.date) }
        guard let first = days.min(), let last = days.max(), day >= first, day <= last else { return nil }
        return DailySpendHoverValue(day: day, amount: 0)
    }

    static func amountText(_ amount: Double) -> String {
        String(format: "$%.2f", amount)
    }
}
