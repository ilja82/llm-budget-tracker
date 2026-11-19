import XCTest

final class DailyActivityEndDateTests: XCTestCase {
    func testBerlinAfterLocalMidnightUsesNewLocalDate() throws {
        XCTAssertEqual(try endDay("2026-05-01T22:18:00Z", zone: "Europe/Berlin"), try utcMidnight("2026-05-02"))
    }

    func testBerlinBeforeLocalMidnightKeepsDate() throws {
        XCTAssertEqual(try endDay("2026-05-01T21:30:00Z", zone: "Europe/Berlin"), try utcMidnight("2026-05-01"))
    }

    func testLosAngelesEveningUsesNextUTCDate() throws {
        XCTAssertEqual(try endDay("2026-05-02T03:00:00Z", zone: "America/Los_Angeles"), try utcMidnight("2026-05-02"))
    }

    func testExactlyLocalMidnightInBerlin() throws {
        XCTAssertEqual(try endDay("2026-05-01T22:00:00Z", zone: "Europe/Berlin"), try utcMidnight("2026-05-02"))
        XCTAssertEqual(try endDay("2026-05-01T21:59:59Z", zone: "Europe/Berlin"), try utcMidnight("2026-05-01"))
    }

    func testDaylightSavingChangeDayInBerlin() throws {
        XCTAssertEqual(try endDay("2026-03-28T23:30:00Z", zone: "Europe/Berlin"), try utcMidnight("2026-03-29"))
        XCTAssertEqual(try endDay("2026-03-29T21:59:00Z", zone: "Europe/Berlin"), try utcMidnight("2026-03-29"))
        XCTAssertEqual(try endDay("2026-03-29T22:00:00Z", zone: "Europe/Berlin"), try utcMidnight("2026-03-30"))
    }

    func testResultIsUTCMidnight() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-05-01T22:18:00Z"))
        let result = dailyActivityEndDate(now: now, localTimeZone: try XCTUnwrap(TimeZone(identifier: "Europe/Berlin")))
        XCTAssertEqual(result, ISO8601DateFormatter().date(from: "2026-05-02T00:00:00Z"))
    }

    private func endDay(_ timestamp: String, zone: String) throws -> Date {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: timestamp))
        let timeZone = try XCTUnwrap(TimeZone(identifier: zone))
        return dailyActivityEndDate(now: now, localTimeZone: timeZone)
    }

    private func utcMidnight(_ day: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: day + "T00:00:00Z"))
    }
}
