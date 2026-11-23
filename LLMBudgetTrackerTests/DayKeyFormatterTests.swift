import XCTest

final class DayKeyFormatterTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_795_392_000) // 2026-11-23T00:00:00Z

    func testFormatsGregorianDayEvenWhenTheFormatterStartsWithABuddhistCalendar() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "th_TH@calendar=buddhist")
        formatter.calendar = Calendar(identifier: .buddhist)

        DayKeyFormatter.configure(formatter)

        XCTAssertEqual(formatter.string(from: fixedDate), "2026-11-23")
        XCTAssertEqual(formatter.date(from: "2026-11-23"), fixedDate)
    }

    func testFormatsGregorianDayEvenWhenTheFormatterStartsWithAJapaneseCalendar() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP@calendar=japanese")
        formatter.calendar = Calendar(identifier: .japanese)

        DayKeyFormatter.configure(formatter)

        XCTAssertEqual(formatter.string(from: fixedDate), "2026-11-23")
    }

    func testMakeUsesUTCDays() {
        XCTAssertEqual(DayKeyFormatter.make().string(from: fixedDate.addingTimeInterval(86_399)), "2026-11-23")
    }

    func testDashboardDateReadsGregorianYearInABuddhistCalendar() throws {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "America/New_York") ?? .current

        let date = try XCTUnwrap(DashboardStats.date(from: "2026-11-23", calendar: buddhist))

        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = buddhist.timeZone
        XCTAssertEqual(gregorian.dateComponents([.year, .month, .day], from: date),
                       DateComponents(year: 2026, month: 11, day: 23))
        XCTAssertEqual(buddhist.component(.weekday, from: date), 2, "2026-11-23 is a Monday")
    }
}
