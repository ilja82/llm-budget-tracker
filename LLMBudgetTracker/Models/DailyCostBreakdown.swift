import Foundation

struct DailyCostPart: Equatable, Identifiable {
    let name: String
    let spend: Double

    var id: String { name }
}

struct DailyCostRow: Equatable, Identifiable {
    let date: String
    let total: Double
    let parts: [DailyCostPart]
    let partsExceedTotal: Bool

    var id: String { date }
}

enum DailyCostBreakdown {
    static let tolerance = 0.005
    static let otherName = "Other / unattributed"
    static let unattributedName = "Unattributed"

    static func rows(from data: [DailySpendData], range: ModelRange, now: Date) -> [DailyCostRow] {
        DashboardStats.days(data, range: range, now: now)
            .sorted { $0.date > $1.date }
            .map(row(for:))
    }

    static func row(for day: DailySpendData) -> DailyCostRow {
        let total = day.metrics.spend
        guard let perModel = day.breakdown?.perModel, !perModel.isEmpty else {
            let parts = total == 0 ? [] : [DailyCostPart(name: unattributedName, spend: total)]
            return DailyCostRow(date: day.date, total: total, parts: parts, partsExceedTotal: false)
        }
        var parts = sortedParts(perModel.map { DailyCostPart(name: $0.key, spend: $0.value.metrics.spend) })
        let difference = total - parts.reduce(0) { $0 + $1.spend }
        if difference > tolerance {
            parts.append(DailyCostPart(name: otherName, spend: difference))
        }
        return DailyCostRow(
            date: day.date,
            total: total,
            parts: parts,
            partsExceedTotal: difference < -tolerance
        )
    }

    static func rangeTotal(_ rows: [DailyCostRow]) -> Double {
        rows.reduce(0) { $0 + $1.total }
    }

    static func sortedParts(_ parts: [DailyCostPart]) -> [DailyCostPart] {
        parts
            .filter { $0.spend != 0 }
            .sorted { $0.spend != $1.spend ? $0.spend > $1.spend : $0.name < $1.name }
    }
}
