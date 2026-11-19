import Foundation

/// A LiteLLM temporary budget increase: `temp_budget_increase` (USD) until `temp_budget_expiry`.
/// LiteLLM enforces `max_budget + amount` while the expiry lies in the future.
struct TemporaryBudgetIncrease: Equatable, Sendable {
    let amount: Double
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case increase = "temp_budget_increase"
        case expiry = "temp_budget_expiry"
    }

    /// The amount to add to the cap at `now`; 0 once the expiry is reached.
    func activeAmount(at now: Date) -> Double {
        amount > 0 && expiresAt > now ? amount : 0
    }

    /// This increase if it is active at `now`, else nil.
    func active(at now: Date) -> Self? {
        activeAmount(at: now) > 0 ? self : nil
    }

    var includedText: String {
        "Includes temporary +\(String(format: "$%.2f", amount)) until \(localExpiryText)"
    }

    var tooltipText: String {
        "Temporary increase: +\(String(format: "$%.2f", amount)) until \(localExpiryText)"
    }

    private var localExpiryText: String {
        expiresAt.formatted(date: .abbreviated, time: .shortened)
    }

    /// Builds an increase from the raw values; nil when the amount is not a positive number
    /// or the expiry is missing or unreadable.
    static func make(increase: Double?, expiry: String?) -> Self? {
        guard let increase, increase.isFinite, increase > 0,
              let expiry, let expiresAt = parseExpiry(expiry) else { return nil }
        return Self(amount: increase, expiresAt: expiresAt)
    }

    /// Reads both fields from a container; a value of the wrong type counts as missing.
    static func decode(from container: KeyedDecodingContainer<CodingKeys>?) -> Self? {
        guard let container else { return nil }
        return make(
            increase: try? container.decodeIfPresent(Double.self, forKey: .increase),
            expiry: try? container.decodeIfPresent(String.self, forKey: .expiry)
        )
    }

    /// Parses `YYYY-MM-DD` or `YYYY-MM-DDThh:mm:ss[.fraction][Z|±hh:mm]`. No zone means UTC.
    static func parseExpiry(_ text: String) -> Date? {
        let bytes = Array(text.utf8)
        guard bytes.count >= 10,
              let year = number(bytes, at: 0, length: 4), bytes[4] == UInt8(ascii: "-"),
              let month = number(bytes, at: 5, length: 2), bytes[7] == UInt8(ascii: "-"),
              let day = number(bytes, at: 8, length: 2) else { return nil }
        let midnight = ParsedTime(hour: 0, minute: 0, second: 0, fraction: 0, offsetSeconds: 0)
        guard let time = bytes.count > 10 ? parseTime(bytes) : midnight,
              (1...12).contains(month), (1...31).contains(day), (0...23).contains(time.hour),
              (0...59).contains(time.minute), (0...59).contains(time.second) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = DateComponents(
            year: year, month: month, day: day, hour: time.hour, minute: time.minute, second: time.second
        )
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day else { return nil }
        return date.addingTimeInterval(time.fraction - Double(time.offsetSeconds))
    }

    private struct ParsedTime {
        let hour: Int
        let minute: Int
        let second: Int
        let fraction: Double
        let offsetSeconds: Int
    }

    private static func parseTime(_ bytes: [UInt8]) -> ParsedTime? {
        guard bytes.count >= 19, bytes[10] == UInt8(ascii: "T"),
              let hour = number(bytes, at: 11, length: 2), bytes[13] == UInt8(ascii: ":"),
              let minute = number(bytes, at: 14, length: 2), bytes[16] == UInt8(ascii: ":"),
              let second = number(bytes, at: 17, length: 2) else { return nil }
        var index = 19
        var fraction = 0.0
        if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
            let start = index + 1
            index = start
            var scale = 0.1
            while index < bytes.count, isDigit(bytes[index]) {
                fraction += Double(bytes[index] - UInt8(ascii: "0")) * scale
                scale /= 10
                index += 1
            }
            guard index > start else { return nil }
        }
        var offsetSeconds = 0
        if index < bytes.count {
            if bytes[index] == UInt8(ascii: "Z") {
                index += 1
            } else {
                guard let offset = parseOffset(bytes, at: index) else { return nil }
                offsetSeconds = offset
                index += 6
            }
        }
        guard index == bytes.count else { return nil }
        return ParsedTime(hour: hour, minute: minute, second: second, fraction: fraction, offsetSeconds: offsetSeconds)
    }

    private static func parseOffset(_ bytes: [UInt8], at index: Int) -> Int? {
        let sign = bytes[index]
        guard sign == UInt8(ascii: "+") || sign == UInt8(ascii: "-"), bytes.count >= index + 6,
              let hours = number(bytes, at: index + 1, length: 2), bytes[index + 3] == UInt8(ascii: ":"),
              let minutes = number(bytes, at: index + 4, length: 2),
              (0...23).contains(hours), (0...59).contains(minutes) else { return nil }
        let seconds = hours * 3_600 + minutes * 60
        return sign == UInt8(ascii: "-") ? -seconds : seconds
    }

    private static func number(_ bytes: [UInt8], at start: Int, length: Int) -> Int? {
        guard start + length <= bytes.count else { return nil }
        var value = 0
        for byte in bytes[start..<(start + length)] {
            guard isDigit(byte) else { return nil }
            value = value * 10 + Int(byte - UInt8(ascii: "0"))
        }
        return value
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }
}
