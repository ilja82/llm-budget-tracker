import Foundation

func dailyActivityEndDate(now: Date, localTimeZone: TimeZone = .current) -> Date {
    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    var localCalendar = Calendar(identifier: .gregorian)
    localCalendar.timeZone = localTimeZone
    let utcDay = utcCalendar.startOfDay(for: now)
    let local = localCalendar.dateComponents([.year, .month, .day], from: now)
    guard let localDay = utcCalendar.date(from: local) else { return utcDay }
    return max(localDay, utcDay)
}
