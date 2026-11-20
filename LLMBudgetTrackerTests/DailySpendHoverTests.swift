import XCTest

final class DailySpendHoverTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ offset: Int, hour: Int = 0) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)) ?? Date()
        let shifted = calendar.date(byAdding: .day, value: offset, to: base) ?? base
        return calendar.date(byAdding: .hour, value: hour, to: shifted) ?? shifted
    }

    private func point(_ offset: Int, _ amount: Double) -> SpendPoint {
        SpendPoint(id: "d\(offset)", date: day(offset), amount: amount)
    }

    func testNearestPointMatchesSameDayAtAnyTime() {
        let points = [point(0, 1), point(1, 2), point(2, 3)]

        XCTAssertEqual(DailySpendHover.nearestPoint(to: day(1, hour: 0), in: points)?.id, "d1")
        XCTAssertEqual(DailySpendHover.nearestPoint(to: day(1, hour: 13), in: points)?.id, "d1")
        XCTAssertEqual(DailySpendHover.nearestPoint(to: day(1, hour: 23), in: points)?.id, "d1")
    }

    func testNearestPointIsNilForEmptyList() {
        XCTAssertNil(DailySpendHover.nearestPoint(to: day(0), in: []))
    }

    func testValueUsesRealAmount() {
        let points = [point(0, 0.004), point(1, 12.5)]

        XCTAssertEqual(DailySpendHover.value(at: day(0, hour: 5), in: points)?.amount, 0.004)
        XCTAssertEqual(DailySpendHover.value(at: day(1, hour: 5), in: points)?.amount, 12.5)
    }

    func testAmountText() {
        XCTAssertEqual(DailySpendHover.amountText(0.004), "$0.00")
        XCTAssertEqual(DailySpendHover.amountText(12.5), "$12.50")
        XCTAssertEqual(DailySpendHover.amountText(0), "$0.00")
        XCTAssertEqual(DailySpendHover.amountText(-0.0), "$0.00")
    }

    func testGapInsideRangeShowsZeroAndOutsideRangeShowsNothing() {
        let points = [point(0, 4), point(2, 6)]

        XCTAssertEqual(DailySpendHover.value(at: day(1, hour: 9), in: points),
                       DailySpendHoverValue(day: day(1), amount: 0))
        XCTAssertNil(DailySpendHover.value(at: day(-1, hour: 9), in: points))
        XCTAssertNil(DailySpendHover.value(at: day(3, hour: 9), in: points))
        XCTAssertNil(DailySpendHover.value(at: day(0), in: []))
    }
}
