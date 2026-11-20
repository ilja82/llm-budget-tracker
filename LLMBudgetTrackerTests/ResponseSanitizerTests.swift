import XCTest

final class ResponseSanitizerTests: XCTestCase {
    func testRedactsAllSensitiveJSONKeysCaseInsensitively() throws {
        let keys = [
            "access_token", "API_KEY", "apikey", "Authorization", "email", "password",
            "refresh_token", "secret", "token", "USER_EMAIL"
        ]
        let input = Dictionary(uniqueKeysWithValues: keys.map { ($0, "fixture-secret") })
        let sanitized = ResponseSanitizer.sanitize(data: try JSONSerialization.data(withJSONObject: input))
        let output = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(sanitized.utf8)) as? [String: String]
        )
        for key in keys {
            XCTAssertEqual(output[key], "[REDACTED]", key)
        }
        XCTAssertFalse(sanitized.contains("fixture-secret"))
    }

    func testRecursivelyRedactsNestedObjectsAndArraysWhilePreservingMetrics() throws {
        let input = #"{"results":[{"spend":3.25,"nested":{"token":"secret"}},{"api_key":"key"}]}"#
        let sanitized = ResponseSanitizer.sanitize(data: Data(input.utf8))
        let output = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(sanitized.utf8)) as? [String: Any]
        )
        let results = try XCTUnwrap(output["results"] as? [[String: Any]])
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0]["spend"] as? Double, 3.25)
        XCTAssertEqual((results[0]["nested"] as? [String: String])?["token"], "[REDACTED]")
        XCTAssertEqual(results[1]["api_key"] as? String, "[REDACTED]")
    }

    func testRedactsTopLevelJSONArray() throws {
        let sanitized = ResponseSanitizer.sanitize(data: Data(#"[{"password":"secret"},42,null]"#.utf8))
        let output = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(sanitized.utf8)) as? [Any])
        XCTAssertEqual((output[0] as? [String: String])?["password"], "[REDACTED]")
        XCTAssertEqual(output[1] as? Int, 42)
        XCTAssertTrue(output[2] is NSNull)
    }

    func testPlainTextRedactsEmailsAndSecretAssignments() {
        let input = "Contact Person@Example.com API_KEY=fixture-key, token:fixture-token password=fixture-password"
        XCTAssertEqual(
            ResponseSanitizer.sanitize(data: Data(input.utf8)),
            "Contact [REDACTED_EMAIL] [REDACTED_SECRET], [REDACTED_SECRET] [REDACTED_SECRET]"
        )
    }

    func testEmptyAndNonUTF8Data() {
        XCTAssertEqual(ResponseSanitizer.sanitize(data: Data()), "")
        XCTAssertEqual(ResponseSanitizer.sanitize(data: Data([0xFF, 0xFE])), "<2 bytes>")
    }

    func testTruncationPreservesTextAtAndBelowLimit() {
        XCTAssertEqual(ResponseSanitizer.truncatedForDisplay("abc", maxLength: 3), "abc")
        XCTAssertEqual(ResponseSanitizer.truncatedForDisplay("ab", maxLength: 3), "ab")
        XCTAssertEqual(ResponseSanitizer.truncatedForDisplay("", maxLength: 0), "")
    }

    func testTruncationRespectsUnicodeCharacterBoundaries() {
        XCTAssertEqual(
            ResponseSanitizer.truncatedForDisplay("👩‍💻é🇩🇪x", maxLength: 3),
            "👩‍💻é🇩🇪\n...[truncated]"
        )
        XCTAssertEqual(ResponseSanitizer.truncatedForDisplay("x", maxLength: 0), "\n...[truncated]")
    }
}
