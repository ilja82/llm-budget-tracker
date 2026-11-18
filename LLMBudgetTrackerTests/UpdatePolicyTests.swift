import XCTest

final class UpdatePolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func release(_ version: String, hoursOld: Double) -> ReleaseInfo {
        ReleaseInfo(version: version, publishedAt: now.addingTimeInterval(-hoursOld * 3600))
    }

    private func update(
        current: String,
        release: ReleaseInfo?,
        dismissed: String? = nil
    ) -> AvailableUpdate? {
        UpdatePolicy.availableUpdate(currentVersion: current, release: release, dismissedVersion: dismissed, now: now)
    }

    func testNewerReleaseThirteenHoursOldIsAvailable() {
        XCTAssertEqual(
            update(current: "0.0.8", release: release("v0.0.9", hoursOld: 13)),
            AvailableUpdate(version: "0.0.9", currentVersion: "0.0.8")
        )
    }

    func testNewerReleaseElevenHoursOldIsNotAvailable() {
        XCTAssertNil(update(current: "0.0.8", release: release("v0.0.9", hoursOld: 11)))
    }

    func testNewerReleaseExactlyTwelveHoursOldIsAvailable() {
        XCTAssertNotNil(update(current: "0.0.8", release: release("v0.0.9", hoursOld: 12)))
    }

    func testSameVersionIsNotAvailable() {
        XCTAssertNil(update(current: "0.0.9", release: release("v0.0.9", hoursOld: 48)))
    }

    func testOlderVersionIsNotAvailable() {
        XCTAssertNil(update(current: "0.1.0", release: release("v0.0.9", hoursOld: 48)))
    }

    func testVersionComponentsCompareNumerically() {
        XCTAssertEqual(update(current: "0.0.9", release: release("v0.0.10", hoursOld: 48))?.version, "0.0.10")
    }

    func testMissingComponentsCountAsZero() {
        XCTAssertNil(update(current: "1.0.0", release: release("v1.0", hoursOld: 48)))
        XCTAssertNil(update(current: "1.0", release: release("v1.0.0", hoursOld: 48)))
        XCTAssertNotNil(update(current: "1.0", release: release("v1.0.1", hoursOld: 48)))
    }

    func testUnparsableTagIsNotAvailable() {
        XCTAssertNil(update(current: "0.0.8", release: release("nightly", hoursOld: 48)))
        XCTAssertNil(UpdatePolicy.release(tagName: "nightly", publishedAt: "2026-11-18T10:00:00Z"))
        XCTAssertNil(UpdatePolicy.parseVersion("v1.0.0-beta"))
        XCTAssertNil(UpdatePolicy.parseVersion("v1..0"))
        XCTAssertNil(UpdatePolicy.parseVersion("v"))
        XCTAssertNil(UpdatePolicy.parseVersion("+1.0"))
    }

    func testUnparsableCurrentVersionIsNotAvailable() {
        XCTAssertNil(update(current: "unknown", release: release("v0.0.9", hoursOld: 48)))
    }

    func testBadDateGivesNoRelease() {
        XCTAssertNil(UpdatePolicy.release(tagName: "v0.0.9", publishedAt: "yesterday"))
        XCTAssertNil(UpdatePolicy.release(tagName: "v0.0.9", publishedAt: ""))
        XCTAssertNil(update(current: "0.0.8", release: UpdatePolicy.release(tagName: "v0.0.9", publishedAt: "bad")))
    }

    func testValidTagAndDateGiveRelease() {
        XCTAssertEqual(
            UpdatePolicy.release(tagName: "v0.0.9", publishedAt: "2027-01-15T08:00:00Z"),
            ReleaseInfo(version: "v0.0.9", publishedAt: now)
        )
    }

    func testDismissedVersionIsHidden() {
        XCTAssertNil(update(current: "0.0.8", release: release("v0.0.9", hoursOld: 48), dismissed: "0.0.9"))
    }

    func testVersionNewerThanDismissedIsShown() {
        XCTAssertEqual(
            update(current: "0.0.8", release: release("v0.0.10", hoursOld: 48), dismissed: "0.0.9")?.version,
            "0.0.10"
        )
    }

    func testCheckIsDueWhenMissingOrTwelveHoursOld() {
        XCTAssertTrue(UpdatePolicy.isCheckDue(lastCheck: nil, now: now))
        XCTAssertTrue(UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(-12 * 3600), now: now))
        XCTAssertFalse(UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(-11 * 3600), now: now))
    }

    func testNextWakeIsTwelveHoursAfterLastCheck() {
        let lastCheck = now.addingTimeInterval(-2 * 3600)
        XCTAssertEqual(
            UpdatePolicy.nextWakeDate(lastCheck: lastCheck, release: nil, now: now),
            now.addingTimeInterval(10 * 3600)
        )
    }

    func testNextWakeAfterFailedCheckIsNextTick() {
        XCTAssertEqual(
            UpdatePolicy.nextWakeDate(lastCheck: now.addingTimeInterval(-20 * 3600), release: nil, now: now),
            now.addingTimeInterval(12 * 3600)
        )
    }

    func testNextWakeIsWhenYoungReleaseBecomesOldEnough() {
        XCTAssertEqual(
            UpdatePolicy.nextWakeDate(lastCheck: now, release: release("v0.0.9", hoursOld: 2), now: now),
            now.addingTimeInterval(10 * 3600)
        )
    }

    func testDecodesGitHubRelease() throws {
        let json = Data(#"{"tag_name":"v0.0.9","published_at":"2026-11-18T10:00:00Z","html_url":"x"}"#.utf8)
        let release = try UpdateChecker.decodeRelease(from: json)
        XCTAssertEqual(release.version, "v0.0.9")
        XCTAssertEqual(release.publishedAt, Date(timeIntervalSince1970: 1_794_996_000))
    }

    func testDecodingRejectsBadTagOrDate() {
        let badTag = Data(#"{"tag_name":"nightly","published_at":"2026-11-18T10:00:00Z"}"#.utf8)
        let badDate = Data(#"{"tag_name":"v0.0.9","published_at":"soon"}"#.utf8)
        XCTAssertThrowsError(try UpdateChecker.decodeRelease(from: badTag))
        XCTAssertThrowsError(try UpdateChecker.decodeRelease(from: badDate))
        XCTAssertThrowsError(try UpdateChecker.decodeRelease(from: Data("not json".utf8)))
    }

    func testRequestSendsOnlyAcceptAndUserAgent() throws {
        let request = try UpdateChecker(version: "1.2.3").makeRequest()
        XCTAssertEqual(request.url?.absoluteString, UpdateChecker.latestReleaseURLString)
        XCTAssertEqual(request.timeoutInterval, 30)
        XCTAssertFalse(request.httpShouldHandleCookies)
        XCTAssertEqual(request.allHTTPHeaderFields, [
            "Accept": "application/vnd.github+json",
            "User-Agent": "LLMBudgetTracker/1.2.3"
        ])
    }
}
