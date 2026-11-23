import XCTest

final class ModelSpendScaleTests: XCTestCase {
    func testLargestSpendFillsTheBar() {
        XCTAssertEqual(ModelSpendScale.fraction(of: 12.5, max: 12.5), 1)
    }

    func testSmallerSpendIsProportional() {
        XCTAssertEqual(ModelSpendScale.fraction(of: 2.5, max: 10), 0.25, accuracy: 1e-9)
    }

    func testZeroOrNegativeMaxGivesEmptyBar() {
        XCTAssertEqual(ModelSpendScale.fraction(of: 3, max: 0), 0)
        XCTAssertEqual(ModelSpendScale.fraction(of: 3, max: -1), 0)
    }

    func testResultIsClampedToUnitRange() {
        XCTAssertEqual(ModelSpendScale.fraction(of: -2, max: 10), 0)
        XCTAssertEqual(ModelSpendScale.fraction(of: 20, max: 10), 1)
        XCTAssertEqual(ModelSpendScale.fraction(of: .nan, max: 10), 0)
    }
}
