import XCTest

final class ConnectionSettingsTests: XCTestCase {
    func testURLChangeWithSavedKeyEnablesActions() {
        let settings = makeSettings(apiKeyConfigured: true)

        XCTAssertTrue(settings.isFormFilled)
        XCTAssertTrue(settings.canSave)
    }

    func testMissingKeyDisablesActions() {
        let settings = makeSettings()

        XCTAssertFalse(settings.isFormFilled)
        XCTAssertFalse(settings.canSave)
    }

    func testNewKeyEnablesActionsWithoutSavedKey() {
        let settings = makeSettings(newAPIKey: "replacement-key")

        XCTAssertTrue(settings.isFormFilled)
        XCTAssertTrue(settings.canSave)
    }

    func testEmptyURLDisablesActionsEvenWithSavedKey() {
        let settings = makeSettings(proxyURL: "", apiKeyConfigured: true)

        XCTAssertFalse(settings.isFormFilled)
        XCTAssertFalse(settings.canSave)
    }

    func testInvalidURLCannotBeSaved() {
        for url in ["not-a-url", "http://proxy.example.com", "   "] {
            let settings = makeSettings(proxyURL: url, apiKeyConfigured: true)

            XCTAssertFalse(settings.canSave, url)
        }
    }

    func testConnectionTestLoadsSavedKey() throws {
        let settings = makeSettings(apiKeyConfigured: true)
        var loadCount = 0

        let apiKey = try settings.apiKeyForTesting {
            loadCount += 1
            return "saved-key"
        }

        XCTAssertEqual(apiKey, "saved-key")
        XCTAssertEqual(loadCount, 1)
    }

    func testConnectionTestPrefersNewKeyWithoutReadingKeychain() throws {
        let settings = makeSettings(newAPIKey: "replacement-key", apiKeyConfigured: true)

        let apiKey = try settings.apiKeyForTesting {
            XCTFail("The saved key must not be read when a replacement was entered")
            return "saved-key"
        }

        XCTAssertEqual(apiKey, "replacement-key")
    }

    func testSavedKeyReadErrorIsPropagated() {
        let settings = makeSettings(apiKeyConfigured: true)

        XCTAssertThrowsError(try settings.apiKeyForTesting { throw MockKeychainError.failed }) { error in
            XCTAssertTrue(error is MockKeychainError)
        }
    }

    func testURLOnlySaveDoesNotWriteKeychain() throws {
        let settings = makeSettings(apiKeyConfigured: true)

        try settings.saveAPIKeyIfNeeded { _ in
            XCTFail("A URL-only change must preserve the saved key without writing to the keychain")
        }
    }

    func testReplacementKeyIsSaved() throws {
        let settings = makeSettings(newAPIKey: "replacement-key", apiKeyConfigured: true)
        var savedKeys: [String] = []

        try settings.saveAPIKeyIfNeeded { savedKeys.append($0) }

        XCTAssertEqual(savedKeys, ["replacement-key"])
    }

    func testKeychainWriteErrorIsPropagated() {
        let settings = makeSettings(newAPIKey: "replacement-key")

        XCTAssertThrowsError(try settings.saveAPIKeyIfNeeded { _ in throw MockKeychainError.failed }) { error in
            XCTAssertTrue(error is MockKeychainError)
        }
    }

    private func makeSettings(
        proxyURL: String = "https://new-proxy.example.com",
        newAPIKey: String = "",
        apiKeyConfigured: Bool = false
    ) -> ConnectionSettings {
        ConnectionSettings(proxyURL: proxyURL, newAPIKey: newAPIKey, apiKeyConfigured: apiKeyConfigured)
    }
}

private enum MockKeychainError: Error {
    case failed
}
