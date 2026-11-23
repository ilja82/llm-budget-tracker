import XCTest

final class TemporaryBudgetIncreaseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_780_272_000)
    private let midnight = Date(timeIntervalSince1970: 1_796_083_200)

    func testActiveAmountBeforeTheExpiry() {
        let increase = TemporaryBudgetIncrease(amount: 50, expiresAt: now.addingTimeInterval(86_400))

        XCTAssertEqual(increase.activeAmount(at: now), 50)
        XCTAssertEqual(increase.active(at: now), increase)
    }

    func testActiveAmountIsZeroAtAndAfterTheExpiry() {
        let expired = TemporaryBudgetIncrease(amount: 50, expiresAt: now.addingTimeInterval(-1))
        let expiringNow = TemporaryBudgetIncrease(amount: 50, expiresAt: now)

        XCTAssertEqual(expired.activeAmount(at: now), 0)
        XCTAssertEqual(expiringNow.activeAmount(at: now), 0)
        XCTAssertNil(expiringNow.active(at: now))
    }

    func testActiveAmountIsZeroForANonPositiveAmount() {
        let increase = TemporaryBudgetIncrease(amount: -5, expiresAt: now.addingTimeInterval(86_400))

        XCTAssertEqual(increase.activeAmount(at: now), 0)
    }

    func testExpiryFormatsAllGiveMidnightUTC() {
        let forms = [
            "2026-12-01T00:00:00",
            "2026-12-01T00:00:00Z",
            "2026-12-01T00:00:00+00:00",
            "2026-12-01T00:00:00.000000Z",
            "2026-12-01T00:00:00.000000",
            "2026-12-01",
            "2026-12-01T01:00:00+01:00",
            "2026-11-30T19:00:00-05:00",
            "2026-12-01 00:00:00",
            "2026-12-01 00:00",
            "2026-12-01T00:00",
            "2026-12-01T00",
            "2026-12-01T01:00:00+0100",
            "2026-12-01T01:00+01",
            "2026-12-01 00:00:00.000000"
        ]

        for form in forms {
            XCTAssertEqual(TemporaryBudgetIncrease.parseExpiry(form), midnight, form)
        }
    }

    func testExpiryKeepsFractionalSeconds() {
        XCTAssertEqual(
            TemporaryBudgetIncrease.parseExpiry("2026-12-01T00:00:00.5Z"), midnight.addingTimeInterval(0.5)
        )
    }

    func testUnreadableExpiryFormsAreRejected() {
        let forms = [
            "tomorrow", "", "2026-12-01T", "2026-12-01_00:00:00", "2026-13-01", "2026-02-30",
            "2026-12-01T24:00:00", "2026-12-01T00:00:00.", "2026-12-01T00:00:00+01:0", "2026-12-01T00:00:00Zx",
            "2026-12-01T00:00.5", "2026-12-01T0", "2026-12-01T00:00:00+"
        ]

        for form in forms {
            XCTAssertNil(TemporaryBudgetIncrease.parseExpiry(form), form)
        }
    }

    func testMakeRejectsMissingOrInvalidValues() {
        XCTAssertNil(TemporaryBudgetIncrease.make(increase: nil, expiry: "2026-12-01"))
        XCTAssertNil(TemporaryBudgetIncrease.make(increase: 0, expiry: "2026-12-01"))
        XCTAssertNil(TemporaryBudgetIncrease.make(increase: -10, expiry: "2026-12-01"))
        XCTAssertNil(TemporaryBudgetIncrease.make(increase: .infinity, expiry: "2026-12-01"))
        XCTAssertNil(TemporaryBudgetIncrease.make(increase: 50, expiry: nil))
        XCTAssertNil(TemporaryBudgetIncrease.make(increase: 50, expiry: "tomorrow"))
        XCTAssertEqual(
            TemporaryBudgetIncrease.make(increase: 50, expiry: "2026-12-01"),
            TemporaryBudgetIncrease(amount: 50, expiresAt: midnight)
        )
    }

    func testActiveKeyIncreaseRaisesTheKeyCap() throws {
        let info = try keyBudget(metadata: #"{"temp_budget_increase":50,"temp_budget_expiry":"2026-06-02T00:00:00Z"}"#)

        XCTAssertEqual(info.maxBudget, 150)
        XCTAssertEqual(info.remainingBudget, 60)
        XCTAssertEqual(info.temporaryIncrease?.amount, 50)
    }

    func testExpiredKeyIncreaseKeepsTheBaseCap() throws {
        let info = try keyBudget(metadata: #"{"temp_budget_increase":50,"temp_budget_expiry":"2026-05-31T23:59:59Z"}"#)

        XCTAssertEqual(info.maxBudget, 100)
        XCTAssertNil(info.temporaryIncrease)
    }

    func testBadKeyIncreaseValuesKeepTheBaseCap() throws {
        let cases = [
            #"{"temp_budget_expiry":"2026-06-02T00:00:00Z"}"#,
            #"{"temp_budget_increase":0,"temp_budget_expiry":"2026-06-02T00:00:00Z"}"#,
            #"{"temp_budget_increase":-50,"temp_budget_expiry":"2026-06-02T00:00:00Z"}"#,
            #"{"temp_budget_increase":"50","temp_budget_expiry":"2026-06-02T00:00:00Z"}"#,
            #"{"temp_budget_increase":50}"#,
            #"{"temp_budget_increase":50,"temp_budget_expiry":"tomorrow"}"#,
            #"{"temp_budget_increase":50,"temp_budget_expiry":12345}"#,
            "null",
            #""not an object""#,
            #"[50]"#
        ]

        for metadata in cases {
            let info = try keyBudget(metadata: metadata)
            XCTAssertEqual(info.maxBudget, 100, metadata)
            XCTAssertNil(info.temporaryIncrease, metadata)
        }
    }

    func testKeyIncreaseWithoutKeyCapIsIgnored() throws {
        let json = #"""
            {"info":{"spend":90,"metadata":{"temp_budget_increase":50,"temp_budget_expiry":"2026-06-02"}}}
            """#
        let details = try XCTUnwrap(JSONDecoder().decode(KeyInfoResponse.self, from: Data(json.utf8)).info)
        let info = details.toBudgetInfo(now: now)

        XCTAssertNil(info.maxBudget)
        XCTAssertNil(info.temporaryIncrease)
    }

    func testKeyIncreaseDoesNotRaiseBudgetWindows() throws {
        let json = #"""
            {"info":{"spend":10,"max_budget":100,
            "metadata":{"temp_budget_increase":50,"temp_budget_expiry":"2026-06-02"},
            "budget_limits":[{"budget_duration":"1d","max_budget":5}],
            "budget_limits_usage":{"1d":{"current_spend":4}}}}
            """#
        let details = try XCTUnwrap(JSONDecoder().decode(KeyInfoResponse.self, from: Data(json.utf8)).info)

        XCTAssertEqual(details.toBudgetInfo(now: now).maxBudget, 150)
        XCTAssertEqual(details.windowBudgets().map(\.maxBudget), [5])
        XCTAssertNil(details.windowBudgets().first?.temporaryIncrease)
    }

    func testActiveMemberIncreaseRaisesTheMemberCap() throws {
        let info = try memberBudget(table: #"""
            {"max_budget":100,"temp_budget_increase":50,"temp_budget_expiry":"2026-06-02T00:00:00.123456Z"}
            """#)

        XCTAssertEqual(info.maxBudget, 150)
        XCTAssertEqual(info.temporaryIncrease?.amount, 50)
    }

    func testExpiredOrBadMemberIncreaseKeepsTheBaseCap() throws {
        let tables = [
            #"{"max_budget":100,"temp_budget_increase":50,"temp_budget_expiry":"2026-05-31T00:00:00"}"#,
            #"{"max_budget":100,"temp_budget_increase":"50","temp_budget_expiry":"2026-06-02"}"#,
            #"{"max_budget":100,"temp_budget_increase":50,"temp_budget_expiry":"soon"}"#,
            #"{"max_budget":100,"metadata":{"temp_budget_increase":50,"temp_budget_expiry":"2026-06-02"}}"#
        ]

        for table in tables {
            let info = try memberBudget(table: table)
            XCTAssertEqual(info.maxBudget, 100, table)
            XCTAssertNil(info.temporaryIncrease, table)
        }
    }

    func testIncreaseTexts() {
        let increase = TemporaryBudgetIncrease(amount: 50, expiresAt: midnight)

        XCTAssertTrue(increase.includedText.hasPrefix("Includes temporary +$50.00 until "))
        XCTAssertTrue(increase.tooltipText.hasPrefix("Temporary increase: +$50.00 until "))
    }

    func testIncreaseIsKeptWithUserIdAndDroppedWithoutLimit() {
        let increase = TemporaryBudgetIncrease(amount: 50, expiresAt: midnight)
        let info = BudgetInfo(
            userId: "", spend: 90, maxBudget: 150, budgetDuration: nil, budgetResetAt: nil, userEmail: nil,
            temporaryIncrease: increase
        )

        XCTAssertEqual(info.withUserId("fixture-user").temporaryIncrease, increase)
        XCTAssertNil(info.withoutBudgetLimit().temporaryIncrease)
    }

    private func keyBudget(metadata: String) throws -> BudgetInfo {
        let json = #"{"info":{"spend":90,"max_budget":100,"metadata":"# + metadata + "}}"
        let response = try JSONDecoder().decode(KeyInfoResponse.self, from: Data(json.utf8))
        return try XCTUnwrap(response.info).toBudgetInfo(now: now)
    }

    private func memberBudget(table: String) throws -> BudgetInfo {
        let json = #"{"user_id":"fixture-user","spend":90,"litellm_budget_table":"# + table + "}"
        return try JSONDecoder().decode(TeamMemberInfoResponse.self, from: Data(json.utf8)).toBudgetInfo(now: now)
    }
}
