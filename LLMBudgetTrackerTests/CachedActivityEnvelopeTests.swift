import XCTest

final class CachedActivityEnvelopeTests: XCTestCase {
    private let day = DailySpendData(date: "2026-10-01", metrics: SpendMetrics(spend: 1))

    func testCacheOfTheSameUserIsUsed() throws {
        let envelope = try roundTrip(CachedActivityEnvelope(userId: "user-a", items: [day]))

        XCTAssertEqual(envelope.items(forUser: "user-a")?.map(\.date), ["2026-10-01"])
    }

    func testCacheOfAnotherUserIsDropped() throws {
        let envelope = try roundTrip(CachedActivityEnvelope(userId: "user-a", items: [day]))

        XCTAssertNil(envelope.items(forUser: "user-b"))
    }

    func testCacheIsShownAtLaunchBeforeTheUserIsKnown() throws {
        let envelope = try roundTrip(CachedActivityEnvelope(userId: "user-a", items: [day]))

        XCTAssertEqual(envelope.items(forUser: nil)?.count, 1)
    }

    func testOlderCacheVersionIsDropped() throws {
        let old = Data(#"{"version":3,"items":[{"date":"2026-10-01","metrics":{"spend":1}}]}"#.utf8)
        let envelope = try JSONDecoder().decode(CachedActivityEnvelope.self, from: old)

        XCTAssertNil(envelope.items(forUser: nil))
        XCTAssertNil(envelope.items(forUser: "user-a"))
    }

    private func roundTrip(_ envelope: CachedActivityEnvelope) throws -> CachedActivityEnvelope {
        try JSONDecoder().decode(CachedActivityEnvelope.self, from: JSONEncoder().encode(envelope))
    }
}
