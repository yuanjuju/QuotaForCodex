import Foundation
import QuotaCore

private struct SmokeFailure: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@main
struct QuotaSmoke {
    static func main() async {
        do {
            try checkMapping()
            try checkStore()
            try await checkClient()
            print("QuotaSmoke passed: mapping, storage, and JSON-RPC")
        } catch {
            let text = "QuotaSmoke failed: \(error.localizedDescription)\n"
            try? FileHandle.standardError.write(contentsOf: Data(text.utf8))
            exit(1)
        }
    }

    private static func checkMapping() throws {
        let overall = RateLimitSnapshotPayload(
            limitId: "codex",
            limitName: nil,
            primary: .init(
                usedPercent: 20,
                windowDurationMins: 300,
                resetsAt: 1_800_000_000
            ),
            secondary: .init(
                usedPercent: 75,
                windowDurationMins: 10_080,
                resetsAt: 1_800_100_000
            ),
            planType: "pro"
        )
        let response = RateLimitsReadResponse(
            rateLimits: overall,
            rateLimitsByLimitId: ["codex": overall]
        )
        let windows = QuotaMapper.windows(from: response)
        try require(windows.count == 2, "Expected two quota windows")
        try require(windows[0].remainingPercent == 80, "Short quota mapping failed")
        try require(windows[1].remainingPercent == 25, "Weekly quota mapping failed")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let points = QuotaMapper.lastSevenDays(
            from: [.init(startDate: "2027-01-15", tokens: 2_000)],
            now: now,
            calendar: calendar
        )
        try require(points.count == 7, "Seven-day fill failed")
    }

    private static func checkStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quota-smoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SnapshotStore(directoryURL: directory)
        let expected = QuotaSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            windows: [
                .init(
                    id: "smoke",
                    durationMinutes: 300,
                    usedPercent: 10,
                    resetsAt: nil
                )
            ],
            status: .ready
        )
        try store.save(expected)
        let actual = try store.load()
        try require(actual == expected, "Snapshot round trip failed")
    }

    private static func checkClient() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quota-rpc-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("fake-codex")
        let script = """
        #!/bin/zsh
        while IFS= read -r line; do
          case "$line" in
            *'"method":"initialize"'*)
              printf '%s\\n' '{"id":1,"result":{"userAgent":"fake/1","codexHome":"/tmp","platformFamily":"unix","platformOs":"macos"}}'
              ;;
            *'"method":"account/rateLimits/read"'*)
              printf '%s\\n' '{"id":2,"result":{"rateLimits":{"limitId":"codex","limitName":null,"primary":{"usedPercent":12,"windowDurationMins":10080,"resetsAt":1800000000},"secondary":null,"planType":"pro"},"rateLimitsByLimitId":null}}'
              ;;
          esac
        done
        """
        try Data(script.utf8).write(to: executable, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        let client = CodexAppServerClient(
            executableURL: executable,
            requestTimeout: .seconds(3)
        )
        try await client.connect()
        let response = try await client.readRateLimits()
        try require(
            response.rateLimits.primary?.usedPercent == 12,
            "JSON-RPC rate-limit response failed"
        )
        await client.disconnect()
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        if !condition() {
            throw SmokeFailure(message: message)
        }
    }
}
