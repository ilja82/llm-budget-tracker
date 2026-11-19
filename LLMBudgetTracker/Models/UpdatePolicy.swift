import Foundation

struct ReleaseInfo: Codable, Equatable, Sendable {
    let version: String
    let publishedAt: Date
}

struct AvailableUpdate: Equatable, Sendable {
    let version: String
    let currentVersion: String
}

enum UpdatePolicy {
    static let checkInterval: TimeInterval = 12 * 3600
    static let minimumReleaseAge: TimeInterval = 12 * 3600
    static let minimumWakeDelay: TimeInterval = 60

    static func parseVersion(_ tag: String) -> [Int]? {
        var text = Substring(tag.trimmingCharacters(in: .whitespaces))
        if text.first == "v" || text.first == "V" {
            text = text.dropFirst()
        }
        guard !text.isEmpty else { return nil }
        var parts: [Int] = []
        for component in text.split(separator: ".", omittingEmptySubsequences: false) {
            guard !component.isEmpty,
                  component.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Int(component) else { return nil }
            parts.append(number)
        }
        return parts
    }

    static func isNewer(_ lhs: [Int], than rhs: [Int]) -> Bool {
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }

    static func parseDate(_ string: String) -> Date? {
        try? Date(string, strategy: .iso8601)
    }

    static func release(tagName: String, publishedAt: String) -> ReleaseInfo? {
        guard parseVersion(tagName) != nil, let date = parseDate(publishedAt) else { return nil }
        return ReleaseInfo(version: tagName, publishedAt: date)
    }

    static func isCheckDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= checkInterval
    }

    static func availableUpdate(
        currentVersion: String,
        release: ReleaseInfo?,
        dismissedVersion: String?,
        now: Date
    ) -> AvailableUpdate? {
        guard let release,
              let latest = parseVersion(release.version),
              let current = parseVersion(currentVersion),
              isNewer(latest, than: current),
              now.timeIntervalSince(release.publishedAt) >= minimumReleaseAge else { return nil }
        if let dismissedVersion, let dismissed = parseVersion(dismissedVersion), !isNewer(latest, than: dismissed) {
            return nil
        }
        return AvailableUpdate(version: displayVersion(latest), currentVersion: currentVersion)
    }

    static func nextWakeDate(lastCheck: Date?, release: ReleaseInfo?, now: Date) -> Date {
        var wake = lastCheck?.addingTimeInterval(checkInterval) ?? now.addingTimeInterval(checkInterval)
        if wake <= now {
            wake = now.addingTimeInterval(checkInterval)
        }
        if let matureAt = release?.publishedAt.addingTimeInterval(minimumReleaseAge), matureAt > now, matureAt < wake {
            wake = matureAt
        }
        return max(wake, now.addingTimeInterval(minimumWakeDelay))
    }

    private static func displayVersion(_ parts: [Int]) -> String {
        parts.map(String.init).joined(separator: ".")
    }
}
