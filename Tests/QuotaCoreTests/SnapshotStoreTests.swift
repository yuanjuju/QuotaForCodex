import Foundation
import XCTest
@testable import QuotaCore

final class SnapshotStoreTests: XCTestCase {
    func testRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SnapshotStore(directoryURL: directory)
        let expected = QuotaSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            sourceVersion: "codex-cli test",
            windows: [
                QuotaWindow(
                    id: "codex-300-primary",
                    durationMinutes: 300,
                    usedPercent: 42,
                    resetsAt: Date(timeIntervalSince1970: 1_800_001_000)
                )
            ],
            dailyUsage: [
                DailyUsagePoint(date: "2026-07-29", tokens: 12_345)
            ],
            status: .ready
        )

        try store.save(expected)
        let actual = try store.load()

        XCTAssertEqual(actual, expected)
    }

    func testMissingFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SnapshotStore(directoryURL: directory)
        XCTAssertNil(try store.load())
    }
}
