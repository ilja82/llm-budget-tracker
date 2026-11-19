import XCTest

private actor FakeUpdateChecker: UpdateChecking {
    private(set) var callCount = 0
    private let result: Result<ReleaseInfo, UpdateCheckError>

    init(result: Result<ReleaseInfo, UpdateCheckError>) {
        self.result = result
    }

    func fetchLatestRelease() async throws -> ReleaseInfo {
        callCount += 1
        return try result.get()
    }
}

final class UpdateViewModelTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "UpdateViewModelTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create defaults suite")
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    private func oldRelease() -> ReleaseInfo {
        ReleaseInfo(version: "v0.0.9", publishedAt: Date.now.addingTimeInterval(-48 * 3600))
    }

    @MainActor
    func testMissingKeyMeansEnabled() {
        let viewModel = UpdateViewModel(
            defaults: makeDefaults(),
            checker: FakeUpdateChecker(result: .failure(.invalidResponse)),
            currentVersion: "0.0.8"
        )
        XCTAssertTrue(viewModel.isEnabled)
    }

    @MainActor
    func testDisabledSendsNoRequestAndShowsNoNotice() async {
        let defaults = makeDefaults()
        defaults.set(false, forKey: StorageKeys.Update.checkEnabled)
        defaults.set("v0.0.9", forKey: StorageKeys.Update.latestVersion)
        defaults.set(oldRelease().publishedAt, forKey: StorageKeys.Update.latestPublishedAt)
        let checker = FakeUpdateChecker(result: .success(oldRelease()))
        let viewModel = UpdateViewModel(defaults: defaults, checker: checker, currentVersion: "0.0.8")

        viewModel.start()
        await viewModel.checkIfDue()
        viewModel.reevaluate()

        XCTAssertFalse(viewModel.isEnabled)
        XCTAssertNil(viewModel.availableUpdate)
        let callCount = await checker.callCount
        XCTAssertEqual(callCount, 0)
    }

    @MainActor
    func testTurningOffHidesNoticeAndTurningOnShowsIt() {
        let defaults = makeDefaults()
        defaults.set("v0.0.9", forKey: StorageKeys.Update.latestVersion)
        defaults.set(oldRelease().publishedAt, forKey: StorageKeys.Update.latestPublishedAt)
        defaults.set(Date.now, forKey: StorageKeys.Update.lastCheck)
        let viewModel = UpdateViewModel(
            defaults: defaults,
            checker: FakeUpdateChecker(result: .failure(.invalidResponse)),
            currentVersion: "0.0.8"
        )
        viewModel.reevaluate()
        XCTAssertEqual(viewModel.availableUpdate?.version, "0.0.9")

        viewModel.isEnabled = false
        XCTAssertNil(viewModel.availableUpdate)
        XCTAssertEqual(defaults.object(forKey: StorageKeys.Update.checkEnabled) as? Bool, false)

        viewModel.isEnabled = true
        XCTAssertEqual(viewModel.availableUpdate?.version, "0.0.9")
    }

    @MainActor
    func testSuccessfulCheckStoresReleaseAndSkipsNextCheckWithinTwelveHours() async {
        let defaults = makeDefaults()
        let checker = FakeUpdateChecker(result: .success(oldRelease()))
        let viewModel = UpdateViewModel(defaults: defaults, checker: checker, currentVersion: "0.0.8")

        await viewModel.checkIfDue()
        await viewModel.checkIfDue()

        XCTAssertEqual(viewModel.availableUpdate, AvailableUpdate(version: "0.0.9", currentVersion: "0.0.8"))
        XCTAssertNotNil(defaults.object(forKey: StorageKeys.Update.lastCheck) as? Date)
        XCTAssertEqual(defaults.string(forKey: StorageKeys.Update.latestVersion), "v0.0.9")
        let callCount = await checker.callCount
        XCTAssertEqual(callCount, 1)
    }

    @MainActor
    func testFailedCheckWritesNoTimestampAndShowsNothing() async {
        let defaults = makeDefaults()
        let checker = FakeUpdateChecker(result: .failure(.httpStatus(403)))
        let viewModel = UpdateViewModel(defaults: defaults, checker: checker, currentVersion: "0.0.8")

        await viewModel.checkIfDue()

        XCTAssertNil(viewModel.availableUpdate)
        XCTAssertNil(defaults.object(forKey: StorageKeys.Update.lastCheck))
        let callCount = await checker.callCount
        XCTAssertEqual(callCount, 1)
    }

    @MainActor
    func testDismissHidesVersionUntilNewerRelease() {
        let defaults = makeDefaults()
        defaults.set("v0.0.9", forKey: StorageKeys.Update.latestVersion)
        defaults.set(oldRelease().publishedAt, forKey: StorageKeys.Update.latestPublishedAt)
        let viewModel = UpdateViewModel(
            defaults: defaults,
            checker: FakeUpdateChecker(result: .failure(.invalidResponse)),
            currentVersion: "0.0.8"
        )
        viewModel.reevaluate()
        viewModel.dismiss()
        XCTAssertNil(viewModel.availableUpdate)
        XCTAssertEqual(defaults.string(forKey: StorageKeys.Update.dismissedVersion), "0.0.9")

        defaults.set("v0.0.10", forKey: StorageKeys.Update.latestVersion)
        viewModel.reevaluate()
        XCTAssertEqual(viewModel.availableUpdate?.version, "0.0.10")
    }

    func testUpdateKeysAreWipedOnReset() {
        let updateKeys = [
            StorageKeys.Update.lastCheck, StorageKeys.Update.latestVersion, StorageKeys.Update.latestPublishedAt,
            StorageKeys.Update.dismissedVersion, StorageKeys.Update.checkEnabled
        ]
        for key in updateKeys {
            XCTAssertTrue(StorageKeys.allKeys.contains(key), key)
        }
    }
}
