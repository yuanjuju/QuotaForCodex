import Foundation
import XCTest
@testable import QuotaCore

final class CodexAppServerClientTests: XCTestCase {
    func testIntegration() async throws {
        let executable = try makeFakeServer()
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let client = CodexAppServerClient(
            executableURL: executable,
            requestTimeout: .seconds(2),
            initializationTimeout: .seconds(5)
        )

        try await client.connect()
        let rateLimits = try await client.readRateLimits()
        XCTAssertEqual(rateLimits.rateLimits.primary?.usedPercent, 12)

        let events = await client.events()
        var iterator = events.makeAsyncIterator()
        let usage = try await client.readUsage()
        XCTAssertEqual(usage.dailyUsageBuckets?.first?.tokens, 1_500_000)
        let event = await iterator.next()
        XCTAssertEqual(event, .rateLimitsChanged)

        await client.disconnect()
    }

    func testTimeout() async throws {
        let executable = try makeFakeServer(ignoreRateLimitRequest: true)
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let client = CodexAppServerClient(
            executableURL: executable,
            requestTimeout: .milliseconds(100),
            // Process startup and the initialize handshake can exceed 100 ms,
            // especially on the first test run after installing Xcode.
            initializationTimeout: .seconds(5)
        )

        try await client.connect()
        do {
            _ = try await client.readRateLimits()
            XCTFail("Expected timeout")
        } catch let error as CodexAppServerClient.ClientError {
            XCTAssertEqual(error.errorDescription?.contains("超时"), true)
        }
        await client.disconnect()
    }

    private func makeFakeServer(ignoreRateLimitRequest: Bool = false) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let executable = directory.appendingPathComponent("fake-codex")
        let rateLimitResponse = ignoreRateLimitRequest
            ? ""
            : #"printf '%s\n' '{"id":2,"result":{"rateLimits":{"limitId":"codex","limitName":null,"primary":{"usedPercent":12,"windowDurationMins":10080,"resetsAt":1800000000},"secondary":null,"planType":"pro"},"rateLimitsByLimitId":null}}'"#
        let script = """
        #!/bin/zsh
        while IFS= read -r line; do
          case "$line" in
            *'"method":"initialize"'*)
              printf '%s\\n' '{"id":1,"result":{"userAgent":"fake-codex/1.0","codexHome":"/tmp","platformFamily":"unix","platformOs":"macos"}}'
              ;;
            *'"method":"account/rateLimits/read"'*)
              \(rateLimitResponse)
              ;;
            *'"method":"account/usage/read"'*)
              printf '%s\\n' '{"id":3,"result":{"summary":{},"dailyUsageBuckets":[{"startDate":"2026-07-29","tokens":1500000}]}}'
              printf '%s\\n' '{"method":"account/rateLimits/updated","params":{"rateLimits":{}}}'
              ;;
          esac
        done
        """
        try Data(script.utf8).write(to: executable, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        return executable
    }
}
