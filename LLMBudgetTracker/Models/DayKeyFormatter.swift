import Foundation

/// Formats and parses the `yyyy-MM-dd` UTC day keys that LiteLLM uses, independent of the user's calendar and locale.
enum DayKeyFormatter {
    static func make() -> DateFormatter {
        configure(DateFormatter())
    }

    @discardableResult
    static func configure(_ formatter: DateFormatter) -> DateFormatter {
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
