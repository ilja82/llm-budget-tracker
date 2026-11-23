import XCTest

final class DashboardStatsTests: XCTestCase {
    private let accuracy = 0.000_001

    func testSummaryTotalsAverageAndMostExpensiveDayPrefersNewestOnTie() throws {
        let data = [
            day("2026-10-01", SpendMetrics(spend: 4, promptTokens: 100, completionTokens: 50,
                                           cacheReadInputTokens: 10, totalTokens: 160,
                                           successfulRequests: 9, failedRequests: 1, apiRequests: 10)),
            day("2026-10-03", SpendMetrics(spend: 4, promptTokens: 200, completionTokens: 100,
                                           cacheReadInputTokens: 20, totalTokens: 320,
                                           successfulRequests: 28, failedRequests: 2, apiRequests: 30)),
            day("2026-10-02", SpendMetrics(spend: 1, totalTokens: 520)),
            day("2026-09-30", SpendMetrics(spend: 50, totalTokens: 1_000, apiRequests: 100)),
        ]

        let summary = DashboardStats.summary(from: data, range: .thisMonth, now: try fixedNow())

        XCTAssertEqual(summary.totalSpend, 9, accuracy: accuracy)
        XCTAssertEqual(summary.activeDays, 3)
        XCTAssertEqual(summary.avgPerActiveDay, 3, accuracy: accuracy)
        XCTAssertEqual(summary.topDay, DashboardTopDay(date: "2026-10-03", spend: 4))
        XCTAssertEqual(summary.requests, 40)
        XCTAssertEqual(summary.failed, 3)
        XCTAssertEqual(summary.failureRate, 7.5, accuracy: accuracy)
        XCTAssertEqual(summary.tokens, 1_000)
        XCTAssertEqual(summary.prompt, 300)
        XCTAssertEqual(summary.completion, 150)
        XCTAssertEqual(summary.cacheRead, 30)
        XCTAssertEqual(try XCTUnwrap(summary.costPer1kTokens), 9, accuracy: accuracy)
    }

    func testPaddedZeroDaysAreNotActiveAndNeverTheMostExpensiveDay() throws {
        let data = [
            day("2026-10-01", SpendMetrics(spend: 6, apiRequests: 3)),
            day("2026-10-02", SpendMetrics()),
            day("2026-10-03", SpendMetrics(apiRequests: 2)),
            day("2026-10-04", SpendMetrics()),
        ]

        let summary = DashboardStats.summary(from: data, range: .thisMonth, now: try fixedNow())

        XCTAssertEqual(summary.activeDays, 2)
        XCTAssertEqual(summary.avgPerActiveDay, 3, accuracy: accuracy)
        XCTAssertEqual(summary.topDay, DashboardTopDay(date: "2026-10-01", spend: 6))
    }

    func testRangeWithOnlyZeroDaysHasNoMostExpensiveDay() throws {
        let data = [day("2026-10-06", SpendMetrics()), day("2026-10-07", SpendMetrics())]

        let summary = DashboardStats.summary(from: data, range: .thisMonth, now: try fixedNow())

        XCTAssertEqual(summary.activeDays, 0)
        XCTAssertEqual(summary.avgPerActiveDay, 0)
        XCTAssertNil(summary.topDay)
    }

    func testFailureRateIsZeroWithoutRequests() throws {
        let summary = DashboardStats.summary(
            from: [day("2026-10-01", SpendMetrics(spend: 1, totalTokens: 10))],
            range: .thisMonth,
            now: try fixedNow()
        )

        XCTAssertEqual(summary.requests, 0)
        XCTAssertEqual(summary.failureRate, 0)
    }

    func testCostPerThousandTokensIsNilWithoutTokens() throws {
        let summary = DashboardStats.summary(
            from: [day("2026-10-01", SpendMetrics(spend: 1, apiRequests: 2))],
            range: .thisMonth,
            now: try fixedNow()
        )

        XCTAssertNil(summary.costPer1kTokens)
    }

    func testEmptyRangeGivesZeroSummary() throws {
        let summary = DashboardStats.summary(from: [], range: .thisMonth, now: try fixedNow())

        XCTAssertEqual(summary.totalSpend, 0)
        XCTAssertEqual(summary.avgPerActiveDay, 0)
        XCTAssertEqual(summary.activeDays, 0)
        XCTAssertNil(summary.topDay)
        XCTAssertNil(summary.costPer1kTokens)
        XCTAssertNil(summary.topModel)
    }

    func testTopModelUsesModelsOverModelGroups() throws {
        let data = [
            DailySpendData(
                date: "2026-10-01",
                metrics: SpendMetrics(spend: 10),
                breakdown: DailyBreakdown(
                    modelGroups: ["group-heavy": breakdown(10)],
                    models: ["model-a": breakdown(3), "model-b": breakdown(7)]
                )
            ),
            DailySpendData(
                date: "2026-10-02",
                metrics: SpendMetrics(spend: 5),
                breakdown: DailyBreakdown(modelGroups: ["model-a": breakdown(5)])
            ),
        ]

        let summary = DashboardStats.summary(from: data, range: .thisMonth, now: try fixedNow())

        XCTAssertEqual(summary.topModel, "model-a")

        let withoutBreakdown = DashboardStats.summary(
            from: [day("2026-10-01", SpendMetrics(spend: 3))],
            range: .thisMonth,
            now: try fixedNow()
        )
        XCTAssertNil(withoutBreakdown.topModel)
    }

    func testModelShareFoldsRestIntoOtherAndSumsToPartsTotal() {
        let models = ["m1": 8.0, "m2": 7.0, "m3": 6.0, "m4": 5.0, "m5": 4.0, "m6": 3.0, "m7": 2.0, "m8": 1.0]
        let data = [
            modelDay("2026-10-01", models: models),
            modelDay("2026-10-02", models: ["m8": 0.5, "zero": 0]),
        ]

        let share = DashboardStats.modelShare(data, top: 6)

        XCTAssertEqual(share.map(\.name), ["m1", "m2", "m3", "m4", "m5", "m6", DashboardStats.otherName])
        XCTAssertEqual(share.last?.spend ?? 0, 3.5, accuracy: accuracy)
        XCTAssertEqual(share.reduce(0) { $0 + $1.spend }, 36.5, accuracy: accuracy)

        let few = DashboardStats.modelShare([modelDay("2026-10-01", models: ["a": 1, "b": 2])], top: 6)
        XCTAssertEqual(few.map(\.name), ["b", "a"])
    }

    func testWeekdaySpendUsesCalendarDateWithoutTimeZoneShift() throws {
        for identifier in ["Pacific/Kiritimati", "Pacific/Pago_Pago", "Europe/Berlin"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: identifier))
            let data = [
                day("2026-10-05", SpendMetrics(spend: 2)),
                day("2026-10-11", SpendMetrics(spend: 3)),
                day("2026-10-12", SpendMetrics(spend: 1)),
            ]

            let weekdays = DashboardStats.weekdaySpend(data, calendar: calendar)

            XCTAssertEqual(weekdays.map(\.label), ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], identifier)
            XCTAssertEqual(weekdays[0].spend, 3, accuracy: accuracy, identifier)
            XCTAssertEqual(weekdays[6].spend, 3, accuracy: accuracy, identifier)
            XCTAssertEqual(weekdays.reduce(0) { $0 + $1.spend }, 6, accuracy: accuracy, identifier)
        }
    }

    func testDaysFilterMatchesDailyCostBreakdown() throws {
        let now = try fixedNow()
        let data = ["2026-09-27", "2026-09-28", "2026-10-04", "2026-10-05", "2026-10-08"]
            .map { modelDay($0, models: ["m": 1]) }

        for range in ModelRange.allCases {
            let statsDates = Set(DashboardStats.days(data, range: range, now: now).map(\.date))
            let rowDates = Set(DailyCostBreakdown.rows(from: data, range: range, now: now).map(\.date))
            XCTAssertEqual(statsDates, rowDates, range.rawValue)
            let summary = DashboardStats.summary(from: data, range: range, now: now)
            XCTAssertEqual(summary.activeDays, rowDates.count, range.rawValue)
        }
        XCTAssertEqual(
            DashboardStats.days(data, range: .lastWeek, now: now).map(\.date),
            ["2026-09-28", "2026-10-04"]
        )
    }

    func testDailySeriesAreSortedOldestFirst() {
        let data = [
            day("2026-10-02", SpendMetrics(promptTokens: 4, completionTokens: 5, cacheReadInputTokens: 6,
                                           successfulRequests: 7, failedRequests: 1)),
            day("2026-10-01", SpendMetrics(promptTokens: 1, completionTokens: 2, cacheReadInputTokens: 3,
                                           successfulRequests: 2, failedRequests: 0)),
        ]

        XCTAssertEqual(DashboardStats.dailyTokens(data), [
            DailyTokenPoint(date: "2026-10-01", kind: DailyTokenPoint.promptKind, value: 1),
            DailyTokenPoint(date: "2026-10-01", kind: DailyTokenPoint.completionKind, value: 2),
            DailyTokenPoint(date: "2026-10-01", kind: DailyTokenPoint.cacheReadKind, value: 3),
            DailyTokenPoint(date: "2026-10-02", kind: DailyTokenPoint.promptKind, value: 4),
            DailyTokenPoint(date: "2026-10-02", kind: DailyTokenPoint.completionKind, value: 5),
            DailyTokenPoint(date: "2026-10-02", kind: DailyTokenPoint.cacheReadKind, value: 6),
        ])
        XCTAssertEqual(DashboardStats.dailyRequests(data), [
            DailyRequestPoint(date: "2026-10-01", ok: 2, failed: 0),
            DailyRequestPoint(date: "2026-10-02", ok: 7, failed: 1),
        ])
    }

    func testDateParsingRejectsInvalidValues() {
        let calendar = Calendar(identifier: .gregorian)
        XCTAssertNil(DashboardStats.date(from: "2026-02-30", calendar: calendar))
        XCTAssertNil(DashboardStats.date(from: "", calendar: calendar))
        XCTAssertNotNil(DashboardStats.date(from: "2028-02-29", calendar: calendar))
    }

    private func fixedNow() throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-08T12:00:00Z"))
    }

    private func day(_ date: String, _ metrics: SpendMetrics) -> DailySpendData {
        DailySpendData(date: date, metrics: metrics)
    }

    private func breakdown(_ spend: Double) -> ModelGroupBreakdown {
        ModelGroupBreakdown(metrics: SpendMetrics(spend: spend))
    }

    private func modelDay(_ date: String, models: [String: Double]) -> DailySpendData {
        DailySpendData(
            date: date,
            metrics: SpendMetrics(spend: models.values.reduce(0, +)),
            breakdown: DailyBreakdown(modelGroups: [:], models: models.mapValues { breakdown($0) })
        )
    }
}
