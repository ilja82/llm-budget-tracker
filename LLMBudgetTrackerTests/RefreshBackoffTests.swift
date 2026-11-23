import XCTest

final class RefreshBackoffTests: XCTestCase {
    func testShortDelaysFollowCappedDoubling() {
        let expected = [30, 60, 120, 240, 300, 300, 300, 300]
        for (index, seconds) in expected.enumerated() {
            XCTAssertEqual(RefreshBackoff.delaySeconds(consecutiveFailures: index + 1), seconds)
        }
    }

    func testLongDelayStartsAfterEighthFailure() {
        for failures in [9, 10, 1000] {
            XCTAssertEqual(RefreshBackoff.delaySeconds(consecutiveFailures: failures), 3600)
        }
    }

    func testLongDelayNeverExceedsTheRefreshInterval() {
        XCTAssertEqual(RefreshBackoff.delaySeconds(consecutiveFailures: 9, intervalSeconds: 300), 300)
        XCTAssertEqual(RefreshBackoff.delaySeconds(consecutiveFailures: 9, intervalSeconds: 900), 900)
        XCTAssertEqual(RefreshBackoff.delaySeconds(consecutiveFailures: 9, intervalSeconds: 3600), 3600)
        XCTAssertEqual(RefreshBackoff.delaySeconds(consecutiveFailures: 9, intervalSeconds: 7200), 3600)
    }

    func testShortDelaysNeverExceedTheRefreshInterval() {
        XCTAssertEqual(RefreshBackoff.delaySeconds(consecutiveFailures: 4, intervalSeconds: 120), 120)
        XCTAssertEqual(RefreshBackoff.delaySeconds(consecutiveFailures: 1, intervalSeconds: 0), 30)
    }

    func testDelayIsMonotonicAndBounded() {
        var previous = 0
        for failures in 1...10000 {
            let seconds = RefreshBackoff.delaySeconds(consecutiveFailures: failures)
            XCTAssertGreaterThanOrEqual(seconds, previous)
            XCTAssertLessThanOrEqual(seconds, 3600)
            previous = seconds
        }
    }
}
