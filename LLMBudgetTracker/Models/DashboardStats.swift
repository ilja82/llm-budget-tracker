import Foundation

struct DashboardTopDay: Equatable {
    let date: String
    let spend: Double
}

struct DashboardSummary: Equatable {
    let totalSpend: Double
    let avgPerActiveDay: Double
    let activeDays: Int
    let topDay: DashboardTopDay?
    let requests: Int
    let failed: Int
    let failureRate: Double
    let tokens: Int
    let prompt: Int
    let completion: Int
    let cacheRead: Int
    let costPer1kTokens: Double?
    let topModel: String?
}

struct DailyTokenPoint: Equatable, Identifiable {
    static let promptKind = "Prompt"
    static let completionKind = "Completion"
    static let cacheReadKind = "Cache read"

    let date: String
    let kind: String
    let value: Int

    var id: String { "\(date)-\(kind)" }
}

struct DailyRequestPoint: Equatable, Identifiable {
    let date: String
    let ok: Int
    let failed: Int

    var id: String { date }
}

struct WeekdaySpend: Equatable, Identifiable {
    static let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    let weekday: Int
    let spend: Double

    var id: Int { weekday }
    var label: String { Self.labels[weekday - 1] }
}

enum DashboardStats {
    static let otherName = "Other"

    static func days(_ data: [DailySpendData], range: ModelRange, now: Date) -> [DailySpendData] {
        guard let dates = range.dateRange(relativeTo: now) else { return [] }
        return data.filter { dates.contains($0.date) }
    }

    static func summary(from data: [DailySpendData], range: ModelRange, now: Date) -> DashboardSummary {
        let days = Self.days(data, range: range, now: now)
        let totalSpend = days.reduce(0) { $0 + $1.metrics.spend }
        let requests = days.reduce(0) { $0 + $1.metrics.apiRequests }
        let failed = days.reduce(0) { $0 + $1.metrics.failedRequests }
        let tokens = days.reduce(0) { $0 + $1.metrics.totalTokens }
        return DashboardSummary(
            totalSpend: totalSpend,
            avgPerActiveDay: days.isEmpty ? 0 : totalSpend / Double(days.count),
            activeDays: days.count,
            topDay: topDay(days),
            requests: requests,
            failed: failed,
            failureRate: requests > 0 ? Double(failed) / Double(requests) * 100 : 0,
            tokens: tokens,
            prompt: days.reduce(0) { $0 + $1.metrics.promptTokens },
            completion: days.reduce(0) { $0 + $1.metrics.completionTokens },
            cacheRead: days.reduce(0) { $0 + $1.metrics.cacheReadInputTokens },
            costPer1kTokens: tokens > 0 ? totalSpend / Double(tokens) * 1000 : nil,
            topModel: modelTotals(days).first?.name
        )
    }

    static func dailyTokens(_ days: [DailySpendData]) -> [DailyTokenPoint] {
        days.sorted { $0.date < $1.date }.flatMap { day in
            [
                DailyTokenPoint(date: day.date, kind: DailyTokenPoint.promptKind, value: day.metrics.promptTokens),
                DailyTokenPoint(
                    date: day.date, kind: DailyTokenPoint.completionKind, value: day.metrics.completionTokens
                ),
                DailyTokenPoint(
                    date: day.date, kind: DailyTokenPoint.cacheReadKind, value: day.metrics.cacheReadInputTokens
                ),
            ]
        }
    }

    static func dailyRequests(_ days: [DailySpendData]) -> [DailyRequestPoint] {
        days.sorted { $0.date < $1.date }.map {
            DailyRequestPoint(date: $0.date, ok: $0.metrics.successfulRequests, failed: $0.metrics.failedRequests)
        }
    }

    static func modelShare(_ days: [DailySpendData], top: Int) -> [DailyCostPart] {
        let totals = modelTotals(days)
        let count = max(top, 0)
        guard totals.count > count else { return totals }
        let rest = totals.dropFirst(count).reduce(0) { $0 + $1.spend }
        return Array(totals.prefix(count)) + [DailyCostPart(name: otherName, spend: rest)]
    }

    static func weekdaySpend(_ days: [DailySpendData], calendar: Calendar) -> [WeekdaySpend] {
        var sums = [Double](repeating: 0, count: 7)
        for day in days {
            guard let date = date(from: day.date, calendar: calendar) else { continue }
            let index = (calendar.component(.weekday, from: date) + 5) % 7
            sums[index] += day.metrics.spend
        }
        return sums.enumerated().map { WeekdaySpend(weekday: $0.offset + 1, spend: $0.element) }
    }

    static func date(from value: String, calendar: Calendar) -> Date? {
        let pieces = value.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3 else { return nil }
        let components = DateComponents(year: pieces[0], month: pieces[1], day: pieces[2], hour: 12)
        guard let date = calendar.date(from: components),
              calendar.component(.month, from: date) == pieces[1],
              calendar.component(.day, from: date) == pieces[2] else { return nil }
        return date
    }

    private static func topDay(_ days: [DailySpendData]) -> DashboardTopDay? {
        var best: DailySpendData?
        for day in days {
            guard let current = best else {
                best = day
                continue
            }
            if day.metrics.spend > current.metrics.spend
                || (day.metrics.spend == current.metrics.spend && day.date > current.date) {
                best = day
            }
        }
        return best.map { DashboardTopDay(date: $0.date, spend: $0.metrics.spend) }
    }

    private static func modelTotals(_ days: [DailySpendData]) -> [DailyCostPart] {
        var totals: [String: Double] = [:]
        for day in days {
            for (name, group) in day.breakdown?.perModel ?? [:] {
                totals[name, default: 0] += group.metrics.spend
            }
        }
        return DailyCostBreakdown.sortedParts(totals.map { DailyCostPart(name: $0.key, spend: $0.value) })
    }
}
