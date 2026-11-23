import XCTest

final class FakeDailyActivityTests: XCTestCase {
    func testModelGroupsMatchTheCurrentModels() {
        XCTAssertEqual(FakeDailyActivity.modelGroups, [
            "Claude Opus 5.5",
            "Claude Sonnet 5.5",
            "Kimi K3.1 Pro",
            "Claude Haiku 5.5",
            "DeepSeek V4.1 Flash 1017",
            "GLM-5.3",
            "GLM-5.3-Flash"
        ])
    }

    func testEachDaySplitsItsTotalsAcrossAllModelGroups() throws {
        let days = FakeDailyActivity.generate(daysPassed: 5, totalSpend: 50)
        XCTAssertEqual(days.count, 5)
        for day in days {
            let perModel = try XCTUnwrap(day.breakdown?.perModel)
            XCTAssertEqual(Set(perModel.keys), Set(FakeDailyActivity.modelGroups))
            let parts = perModel.values.map(\.metrics)
            XCTAssertEqual(parts.map(\.spend).reduce(0, +), day.metrics.spend, accuracy: 0.000_001)
            XCTAssertEqual(parts.map(\.promptTokens).reduce(0, +), day.metrics.promptTokens)
            XCTAssertEqual(parts.map(\.apiRequests).reduce(0, +), day.metrics.apiRequests)
        }
    }
}
