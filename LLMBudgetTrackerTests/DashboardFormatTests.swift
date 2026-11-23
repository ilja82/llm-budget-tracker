import XCTest

final class DashboardFormatTests: XCTestCase {
    func testAxisDollarsKeepsCentsForSmallSpend() {
        let labels = [0, 0.25, 0.5, 0.75, 1, 1.25].map { DashboardFormat.axisDollars($0, maxValue: 1.2) }
        XCTAssertEqual(labels, ["$0.00", "$0.25", "$0.50", "$0.75", "$1.00", "$1.25"])
        XCTAssertEqual(Set(labels).count, labels.count)
    }

    func testAxisDollarsKeepsCentsJustBelowTheThreshold() {
        XCTAssertEqual(DashboardFormat.axisDollars(2.5, maxValue: 9.99), "$2.50")
    }

    func testAxisDollarsDropsCentsForLargeSpend() {
        XCTAssertEqual(DashboardFormat.axisDollars(20, maxValue: 10), "$20")
        XCTAssertEqual(DashboardFormat.axisDollars(150, maxValue: 180), "$150")
    }
}
