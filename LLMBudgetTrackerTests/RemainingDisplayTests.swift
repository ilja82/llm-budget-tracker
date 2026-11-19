import XCTest

final class RemainingDisplayTests: XCTestCase {
    private func info(spend: Double, max: Double?) -> BudgetInfo {
        BudgetInfo(
            userId: "u", spend: spend, maxBudget: max,
            budgetDuration: nil, budgetResetAt: nil, userEmail: nil
        )
    }

    func testPercentTextCountsDownWhenRemaining() {
        XCTAssertEqual(info(spend: 40, max: 100).usageText(.percentage, showRemaining: true), "60%")
        XCTAssertEqual(info(spend: 120, max: 100).usageText(.percentage, showRemaining: true), "0%")
        XCTAssertEqual(info(spend: 0, max: 100).usageText(.percentage, showRemaining: true), "100%")
    }

    func testPercentTextUnchangedWhenOff() {
        XCTAssertEqual(info(spend: 40, max: 100).usageText(.percentage, showRemaining: false), "40%")
        XCTAssertEqual(info(spend: 0, max: 100).usageText(.percentage, showRemaining: false), "0%")
        XCTAssertEqual(info(spend: 120, max: 100).usageText(.percentage, showRemaining: false), "120%")
        XCTAssertEqual(info(spend: 40, max: 100).usageText(.percentage), "40%")
    }

    func testDollarTextIgnoresRemaining() {
        XCTAssertEqual(info(spend: 40, max: 100).usageText(.dollar, showRemaining: true), "$40.00")
    }

    func testFillFractionOn() {
        XCTAssertEqual(info(spend: 40, max: 100).fillFraction(showRemaining: true), 0.6, accuracy: 0.0001)
        XCTAssertEqual(info(spend: 120, max: 100).fillFraction(showRemaining: true), 0)
        XCTAssertEqual(info(spend: 0, max: 100).fillFraction(showRemaining: true), 1)
    }

    func testFillFractionOff() {
        XCTAssertEqual(info(spend: 40, max: 100).fillFraction(showRemaining: false), 0.4, accuracy: 0.0001)
        XCTAssertEqual(info(spend: 120, max: 100).fillFraction(showRemaining: false), 1)
        XCTAssertEqual(info(spend: 0, max: 100).fillFraction(showRemaining: false), 0)
    }

    func testFillFractionWithoutBudgetIsZero() {
        for on in [true, false] {
            XCTAssertEqual(info(spend: 5, max: nil).fillFraction(showRemaining: on), 0)
            XCTAssertEqual(info(spend: 5, max: 0).fillFraction(showRemaining: on), 0)
        }
    }

    func testFillFractionNegativeSpendFollowsFormula() {
        XCTAssertEqual(info(spend: -10, max: 100).fillFraction(showRemaining: true), 1.1, accuracy: 0.0001)
    }

    func testPreferenceDefaultsToFalseAndPersists() throws {
        let name = "RemainingDisplayTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { suite.removePersistentDomain(forName: name) }
        XCTAssertFalse(StorageKeys.loadShowRemaining(from: suite))
        StorageKeys.saveShowRemaining(true, to: suite)
        let reread = try XCTUnwrap(UserDefaults(suiteName: name))
        XCTAssertTrue(StorageKeys.loadShowRemaining(from: reread))
        XCTAssertTrue(StorageKeys.allKeys.contains(StorageKeys.App.showRemaining))
    }
}
