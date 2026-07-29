import Foundation
import XCTest
@testable import QuotaCore

final class QuotaMapperTests: XCTestCase {
    func testOverallBucketWins() {
        let response = RateLimitsReadResponse(
            rateLimits: snapshot(id: "legacy", used: 99, duration: 60),
            rateLimitsByLimitId: [
                "codex": RateLimitSnapshotPayload(
                    limitId: "codex",
                    limitName: nil,
                    primary: RateLimitWindowPayload(
                        usedPercent: 25,
                        windowDurationMins: 300,
                        resetsAt: 1_800_000_000
                    ),
                    secondary: RateLimitWindowPayload(
                        usedPercent: 80,
                        windowDurationMins: 10_080,
                        resetsAt: 1_800_100_000
                    ),
                    planType: "pro"
                ),
                "codex_model": snapshot(id: "codex_model", used: 100, duration: 300)
            ]
        )

        let windows = QuotaMapper.windows(from: response)

        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].remainingPercent, 75)
        XCTAssertEqual(windows[0].displayLabel, "5h")
        XCTAssertEqual(windows[1].remainingPercent, 20)
        XCTAssertEqual(windows[1].displayLabel, "Week")
    }

    func testMissingShortWindow() {
        let response = RateLimitsReadResponse(
            rateLimits: snapshot(id: "codex", used: 15, duration: 10_080),
            rateLimitsByLimitId: nil
        )

        let result = QuotaMapper.snapshot(
            rateLimits: response,
            usage: nil,
            sourceVersion: "test",
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertNil(result.fiveHourWindow)
        XCTAssertEqual(result.weeklyWindow?.remainingPercent, 85)
    }

    func testClampsPercentages() {
        XCTAssertEqual(
            QuotaWindow(
                id: "low",
                durationMinutes: 300,
                usedPercent: -20,
                resetsAt: nil
            ).remainingPercent,
            100
        )
        XCTAssertEqual(
            QuotaWindow(
                id: "high",
                durationMinutes: 300,
                usedPercent: 120,
                resetsAt: nil
            ).remainingPercent,
            0
        )
    }

    private func snapshot(
        id: String,
        used: Int,
        duration: Int
    ) -> RateLimitSnapshotPayload {
        RateLimitSnapshotPayload(
            limitId: id,
            limitName: nil,
            primary: RateLimitWindowPayload(
                usedPercent: used,
                windowDurationMins: duration,
                resetsAt: nil
            ),
            secondary: nil,
            planType: nil
        )
    }
}
