import XCTest

final class BudgetDurationTests: XCTestCase {
    func testWeeksAreSevenDaysEach() {
        XCTAssertEqual(BudgetDuration.days("1w"), 7)
        XCTAssertEqual(BudgetDuration.days("2w"), 14)
        XCTAssertEqual(BudgetDuration.days("weekly"), 7)
    }

    func testOtherUnits() {
        XCTAssertEqual(BudgetDuration.days("30d"), 30)
        XCTAssertEqual(BudgetDuration.days("24h"), 1)
        XCTAssertEqual(BudgetDuration.days("25h"), 2)
        XCTAssertEqual(BudgetDuration.days("90s"), 1)
        XCTAssertEqual(BudgetDuration.days("60m"), 1)
        XCTAssertEqual(BudgetDuration.days("1mo"), 30)
        XCTAssertEqual(BudgetDuration.days("3mo"), 90)
        XCTAssertEqual(BudgetDuration.days("0d"), 1)
    }

    func testIndefiniteHasNoLength() {
        XCTAssertNil(BudgetDuration.days("indefinite"))
        XCTAssertNil(BudgetDuration.days("never"))
    }

    func testUnknownFallsBackToThirtyDays() {
        XCTAssertEqual(BudgetDuration.days("abc"), 30)
    }
}
