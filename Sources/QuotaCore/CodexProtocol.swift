import Foundation

public struct InitializeParams: Codable, Sendable {
    public struct ClientInfo: Codable, Sendable {
        public let name: String
        public let title: String
        public let version: String

        public init(name: String, title: String, version: String) {
            self.name = name
            self.title = title
            self.version = version
        }
    }

    public struct Capabilities: Codable, Sendable {
        public let experimentalApi: Bool

        public init(experimentalApi: Bool = false) {
            self.experimentalApi = experimentalApi
        }
    }

    public let clientInfo: ClientInfo
    public let capabilities: Capabilities

    public init(clientInfo: ClientInfo, capabilities: Capabilities = .init()) {
        self.clientInfo = clientInfo
        self.capabilities = capabilities
    }
}

public struct InitializeResponse: Codable, Equatable, Sendable {
    public let userAgent: String?
    public let codexHome: String?
    public let platformFamily: String?
    public let platformOs: String?

    public init(
        userAgent: String?,
        codexHome: String?,
        platformFamily: String?,
        platformOs: String?
    ) {
        self.userAgent = userAgent
        self.codexHome = codexHome
        self.platformFamily = platformFamily
        self.platformOs = platformOs
    }
}

public struct RateLimitWindowPayload: Codable, Equatable, Sendable {
    public let usedPercent: Int
    public let windowDurationMins: Int?
    public let resetsAt: Int64?

    public init(usedPercent: Int, windowDurationMins: Int?, resetsAt: Int64?) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }
}

public struct RateLimitSnapshotPayload: Codable, Equatable, Sendable {
    public let limitId: String?
    public let limitName: String?
    public let primary: RateLimitWindowPayload?
    public let secondary: RateLimitWindowPayload?
    public let planType: String?

    public init(
        limitId: String?,
        limitName: String?,
        primary: RateLimitWindowPayload?,
        secondary: RateLimitWindowPayload?,
        planType: String?
    ) {
        self.limitId = limitId
        self.limitName = limitName
        self.primary = primary
        self.secondary = secondary
        self.planType = planType
    }
}

public struct RateLimitsReadResponse: Codable, Equatable, Sendable {
    public let rateLimits: RateLimitSnapshotPayload
    public let rateLimitsByLimitId: [String: RateLimitSnapshotPayload]?

    public init(
        rateLimits: RateLimitSnapshotPayload,
        rateLimitsByLimitId: [String: RateLimitSnapshotPayload]?
    ) {
        self.rateLimits = rateLimits
        self.rateLimitsByLimitId = rateLimitsByLimitId
    }
}

public struct AccountUsageSummary: Codable, Equatable, Sendable {
    public let lifetimeTokens: Int64?
    public let peakDailyTokens: Int64?
    public let longestRunningTurnSec: Int64?
    public let currentStreakDays: Int64?
    public let longestStreakDays: Int64?

    public init(
        lifetimeTokens: Int64? = nil,
        peakDailyTokens: Int64? = nil,
        longestRunningTurnSec: Int64? = nil,
        currentStreakDays: Int64? = nil,
        longestStreakDays: Int64? = nil
    ) {
        self.lifetimeTokens = lifetimeTokens
        self.peakDailyTokens = peakDailyTokens
        self.longestRunningTurnSec = longestRunningTurnSec
        self.currentStreakDays = currentStreakDays
        self.longestStreakDays = longestStreakDays
    }
}

public struct AccountUsageDailyBucket: Codable, Equatable, Sendable {
    public let startDate: String
    public let tokens: Int64

    public init(startDate: String, tokens: Int64) {
        self.startDate = startDate
        self.tokens = tokens
    }
}

public struct AccountUsageReadResponse: Codable, Equatable, Sendable {
    public let summary: AccountUsageSummary
    public let dailyUsageBuckets: [AccountUsageDailyBucket]?

    public init(
        summary: AccountUsageSummary,
        dailyUsageBuckets: [AccountUsageDailyBucket]?
    ) {
        self.summary = summary
        self.dailyUsageBuckets = dailyUsageBuckets
    }
}

struct RPCRequest<Params: Encodable>: Encodable {
    let id: Int
    let method: String
    let params: Params
}

struct RPCNotification<Params: Encodable>: Encodable {
    let method: String
    let params: Params?
}

struct NullParams: Encodable, Sendable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

public struct RPCRemoteError: Error, Codable, Equatable, LocalizedError, Sendable {
    public let code: Int?
    public let message: String

    public var errorDescription: String? { message }
}

public enum CodexEvent: Equatable, Sendable {
    case connected(userAgent: String?)
    case rateLimitsChanged
    case disconnected(reason: String)
}
