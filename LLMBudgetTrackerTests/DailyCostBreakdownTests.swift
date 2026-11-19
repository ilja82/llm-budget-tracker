import XCTest

final class DailyCostBreakdownTests: XCTestCase {
    private let accuracy = 0.000_001

    func testPartsAreSortedBySpendThenNameAndSumToTotal() throws {
        let day = makeDay("2026-10-01", spend: 6, models: ["b-model": 2, "a-model": 2, "big": 2])
        let row = DailyCostBreakdown.row(for: day)

        XCTAssertEqual(row.total, 6)
        XCTAssertEqual(row.parts.map(\.name), ["a-model", "b-model", "big"])
        XCTAssertEqual(row.parts.reduce(0) { $0 + $1.spend }, row.total, accuracy: accuracy)
        XCTAssertFalse(row.partsExceedTotal)

        let ranked = DailyCostBreakdown.row(for: makeDay("2026-10-01", spend: 6, models: ["small": 1, "large": 5]))
        XCTAssertEqual(ranked.parts, [part("large", 5), part("small", 1)])
    }

    func testModelsArePreferredOverModelGroupsAndNeverSummed() {
        let day = DailySpendData(
            date: "2026-10-01",
            metrics: SpendMetrics(spend: 3),
            breakdown: DailyBreakdown(
                modelGroups: ["group": breakdown(3)],
                models: ["model-a": breakdown(2), "model-b": breakdown(1)]
            )
        )
        let row = DailyCostBreakdown.row(for: day)

        XCTAssertEqual(row.parts, [part("model-a", 2), part("model-b", 1)])
        XCTAssertFalse(row.partsExceedTotal)

        let groupsOnly = DailySpendData(
            date: "2026-10-01",
            metrics: SpendMetrics(spend: 3),
            breakdown: DailyBreakdown(modelGroups: ["group": breakdown(3)])
        )
        XCTAssertEqual(DailyCostBreakdown.row(for: groupsOnly).parts, [part("group", 3)])
    }

    func testMissingBreakdownGivesUnattributedPart() {
        let row = DailyCostBreakdown.row(for: DailySpendData(date: "2026-10-01", metrics: SpendMetrics(spend: 4.2)))

        XCTAssertEqual(row.total, 4.2)
        XCTAssertEqual(row.parts, [part(DailyCostBreakdown.unattributedName, 4.2)])
        XCTAssertFalse(row.partsExceedTotal)

        let emptyBreakdown = DailySpendData(
            date: "2026-10-01",
            metrics: SpendMetrics(spend: 1),
            breakdown: DailyBreakdown(modelGroups: [:])
        )
        XCTAssertEqual(
            DailyCostBreakdown.row(for: emptyBreakdown).parts,
            [part(DailyCostBreakdown.unattributedName, 1)]
        )
    }

    func testPartsBelowTotalAddOtherUnattributedWithDifference() throws {
        let row = DailyCostBreakdown.row(for: makeDay("2026-10-01", spend: 10, models: ["model-a": 6, "model-b": 3]))

        XCTAssertEqual(row.parts.map(\.name), ["model-a", "model-b", DailyCostBreakdown.otherName])
        let other = try XCTUnwrap(row.parts.last)
        XCTAssertEqual(other.spend, 1, accuracy: accuracy)
        XCTAssertFalse(row.partsExceedTotal)
        XCTAssertEqual(row.total, 10)
    }

    func testDifferenceWithinToleranceAddsNoOtherPart() {
        let row = DailyCostBreakdown.row(for: makeDay("2026-10-01", spend: 1.004, models: ["model-a": 1]))

        XCTAssertEqual(row.parts, [part("model-a", 1)])
        XCTAssertFalse(row.partsExceedTotal)
        XCTAssertEqual(row.total, 1.004)
    }

    func testPartsAboveTotalSetFlagAndKeepReportedTotal() {
        let row = DailyCostBreakdown.row(for: makeDay("2026-10-01", spend: 5, models: ["model-a": 4, "model-b": 2]))

        XCTAssertTrue(row.partsExceedTotal)
        XCTAssertEqual(row.total, 5)
        XCTAssertEqual(row.parts, [part("model-a", 4), part("model-b", 2)])
    }

    func testLastWeekRangeKeepsOnlyPreviousCalendarWeek() throws {
        let now = try fixedNow()
        let data = [
            makeDay("2026-09-27", spend: 1, models: ["m": 1]),
            makeDay("2026-09-28", spend: 2, models: ["m": 2]),
            makeDay("2026-10-04", spend: 3, models: ["m": 3]),
            makeDay("2026-10-05", spend: 4, models: ["m": 4]),
            makeDay("2026-10-08", spend: 5, models: ["m": 5]),
        ]

        let rows = DailyCostBreakdown.rows(from: data, range: .lastWeek, now: now)

        XCTAssertEqual(rows.map(\.date), ["2026-10-04", "2026-09-28"])
    }

    func testRowsAreNewestFirstAndZeroPartsDropped() throws {
        let now = try fixedNow()
        let data = [
            makeDay("2026-10-02", spend: 1, models: ["used": 1, "idle": 0]),
            makeDay("2026-10-07", spend: 2, models: ["used": 2]),
            makeDay("2026-10-05", spend: 3, models: ["used": 3, "idle": 0]),
        ]

        let rows = DailyCostBreakdown.rows(from: data, range: .thisMonth, now: now)

        XCTAssertEqual(rows.map(\.date), ["2026-10-07", "2026-10-05", "2026-10-02"])
        XCTAssertTrue(rows.allSatisfy { $0.parts.map(\.name) == ["used"] })
    }

    func testRangeTotalEqualsSumOfDailyReportedSpend() throws {
        let now = try fixedNow()
        let data = [
            makeDay("2026-10-01", spend: 1.25, models: ["m": 1]),
            makeDay("2026-10-02", spend: 2.5, models: ["m": 3]),
            DailySpendData(date: "2026-10-03", metrics: SpendMetrics(spend: 0.75)),
            makeDay("2026-09-30", spend: 100, models: ["m": 100]),
        ]

        let rows = DailyCostBreakdown.rows(from: data, range: .thisMonth, now: now)

        XCTAssertEqual(DailyCostBreakdown.rangeTotal(rows), 4.5, accuracy: accuracy)
        let expected = data.filter { $0.date.hasPrefix("2026-10") }.reduce(0) { $0 + $1.metrics.spend }
        XCTAssertEqual(DailyCostBreakdown.rangeTotal(rows), expected, accuracy: accuracy)
    }

    func testEmptyRangeGivesNoRows() throws {
        let rows = DailyCostBreakdown.rows(
            from: [makeDay("2026-09-01", spend: 1, models: ["m": 1])],
            range: .thisWeek,
            now: try fixedNow()
        )

        XCTAssertTrue(rows.isEmpty)
        XCTAssertEqual(DailyCostBreakdown.rangeTotal(rows), 0)
    }

    private func fixedNow() throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-08T12:00:00Z"))
    }

    private func part(_ name: String, _ spend: Double) -> DailyCostPart {
        DailyCostPart(name: name, spend: spend)
    }

    private func breakdown(_ spend: Double) -> ModelGroupBreakdown {
        ModelGroupBreakdown(metrics: SpendMetrics(spend: spend))
    }

    private func makeDay(_ date: String, spend: Double, models: [String: Double]) -> DailySpendData {
        DailySpendData(
            date: date,
            metrics: SpendMetrics(spend: spend),
            breakdown: DailyBreakdown(modelGroups: [:], models: models.mapValues { breakdown($0) })
        )
    }
}
