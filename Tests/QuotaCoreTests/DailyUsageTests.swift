import Foundation
import XCTest
@testable import QuotaCore

final class DailyUsageTests: XCTestCase {
    func testZeroFill() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-07-29T12:00:00Z")
        )
        let buckets = [
            AccountUsageDailyBucket(startDate: "2026-07-23", tokens: 500),
            AccountUsageDailyBucket(startDate: "2026-07-29", tokens: 2_000),
            AccountUsageDailyBucket(startDate: "2026-07-29", tokens: 3_000)
        ]

        let points = QuotaMapper.lastSevenDays(
            from: buckets,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(points.count, 7)
        XCTAssertEqual(points.first?.date, "2026-07-23")
        XCTAssertEqual(points.first?.tokens, 500)
        XCTAssertEqual(points.last?.date, "2026-07-29")
        XCTAssertEqual(points.last?.tokens, 5_000)
        XCTAssertEqual(points[1].tokens, 0)
    }

    func testTokenScale() {
        XCTAssertEqual(TokenScale.best(for: [.init(date: "a", tokens: 50)]), .tokens)
        XCTAssertEqual(TokenScale.best(for: [.init(date: "a", tokens: 5_000)]), .thousands)
        XCTAssertEqual(TokenScale.best(for: [.init(date: "a", tokens: 5_000_000)]), .millions)
    }
}
