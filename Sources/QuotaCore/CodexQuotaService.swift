import Foundation

public actor CodexQuotaService {
    private var client: CodexAppServerClient?
    private var executableURL: URL?
    private var sourceVersion: String?

    public init() {}

    public func start(customPath: String? = nil) async throws {
        if client != nil { return }
        let executable = try CodexExecutableLocator.locate(customPath: customPath)
        let version = try? CodexExecutableLocator.version(at: executable)
        let client = CodexAppServerClient(executableURL: executable)
        try await client.connect()
        executableURL = executable
        sourceVersion = version
        self.client = client
    }

    public func restart(customPath: String? = nil) async throws {
        if let client {
            await client.disconnect()
        }
        client = nil
        executableURL = nil
        sourceVersion = nil
        try await start(customPath: customPath)
    }

    public func stop() async {
        if let client {
            await client.disconnect()
        }
        client = nil
        executableURL = nil
        sourceVersion = nil
    }

    public func events() async throws -> AsyncStream<CodexEvent> {
        guard let client else {
            throw CodexAppServerClient.ClientError.processNotRunning
        }
        return await client.events()
    }

    public func fetchSnapshot(
        includeUsage: Bool,
        previous: QuotaSnapshot?,
        now: Date = .now,
        calendar: Calendar = .current
    ) async throws -> QuotaSnapshot {
        guard let client else {
            throw CodexAppServerClient.ClientError.processNotRunning
        }

        if includeUsage {
            async let rateLimitsTask = client.readRateLimits()
            async let usageTask: AccountUsageReadResponse? = try? await client.readUsage()
            let rateLimits = try await rateLimitsTask
            let usage = await usageTask
            return QuotaMapper.snapshot(
                rateLimits: rateLimits,
                usage: usage,
                previous: previous,
                sourceVersion: sourceVersion,
                now: now,
                calendar: calendar
            )
        } else {
            let rateLimits = try await client.readRateLimits()
            return QuotaMapper.snapshot(
                rateLimits: rateLimits,
                usage: nil,
                previous: previous,
                sourceVersion: sourceVersion,
                now: now,
                calendar: calendar
            )
        }
    }

    public func currentExecutablePath() -> String? {
        executableURL?.path
    }
}
