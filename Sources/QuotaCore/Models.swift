import Foundation

public enum QuotaConstants {
    public static let appGroupIdentifier = "group.com.jinian.QuotaForCodex"
    public static let widgetKind = "com.jinian.QuotaForCodex.Widget"
    public static let snapshotSchemaVersion = 1
    public static let fiveHoursInMinutes = 300
    public static let oneWeekInMinutes = 10_080
    public static let staleAfter: TimeInterval = 30 * 60
}

public enum SyncStatus: String, Codable, CaseIterable, Sendable {
    case loading
    case ready
    case notInstalled
    case notLoggedIn
    case incompatible
    case offline
    case stale
    case failed

    public var defaultMessage: String {
        switch self {
        case .loading:
            "正在连接 Codex…"
        case .ready:
            "额度已更新"
        case .notInstalled:
            "未找到 Codex"
        case .notLoggedIn:
            "请先登录 Codex"
        case .incompatible:
            "当前 Codex 版本不兼容"
        case .offline:
            "网络不可用"
        case .stale:
            "显示的是缓存数据"
        case .failed:
            "暂时无法读取额度"
        }
    }
}

public struct QuotaWindow: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let durationMinutes: Int?
    public let usedPercent: Int
    public let resetsAt: Date?

    public init(
        id: String,
        durationMinutes: Int?,
        usedPercent: Int,
        resetsAt: Date?
    ) {
        self.id = id
        self.durationMinutes = durationMinutes
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Int {
        min(max(100 - usedPercent, 0), 100)
    }

    public var displayLabel: String {
        switch durationMinutes {
        case QuotaConstants.fiveHoursInMinutes:
            "5h"
        case QuotaConstants.oneWeekInMinutes:
            "Week"
        case let minutes? where minutes.isMultiple(of: 1_440):
            "\(minutes / 1_440)d"
        case let minutes? where minutes.isMultiple(of: 60):
            "\(minutes / 60)h"
        case let minutes?:
            "\(minutes)m"
        case nil:
            "Quota"
        }
    }
}

public struct DailyUsagePoint: Codable, Equatable, Identifiable, Sendable {
    public let date: String
    public let tokens: Int64

    public init(date: String, tokens: Int64) {
        self.date = date
        self.tokens = max(tokens, 0)
    }

    public var id: String { date }
}

public struct QuotaSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var fetchedAt: Date
    public var sourceVersion: String?
    public var windows: [QuotaWindow]
    public var dailyUsage: [DailyUsagePoint]
    public var status: SyncStatus
    public var statusMessage: String?

    public init(
        schemaVersion: Int = QuotaConstants.snapshotSchemaVersion,
        fetchedAt: Date = .now,
        sourceVersion: String? = nil,
        windows: [QuotaWindow] = [],
        dailyUsage: [DailyUsagePoint] = [],
        status: SyncStatus,
        statusMessage: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.fetchedAt = fetchedAt
        self.sourceVersion = sourceVersion
        self.windows = windows
        self.dailyUsage = dailyUsage
        self.status = status
        self.statusMessage = statusMessage
    }

    public static func empty(
        status: SyncStatus = .loading,
        message: String? = nil,
        now: Date = .now
    ) -> QuotaSnapshot {
        QuotaSnapshot(
            fetchedAt: now,
            status: status,
            statusMessage: message
        )
    }

    public var fiveHourWindow: QuotaWindow? {
        windows.first { $0.durationMinutes == QuotaConstants.fiveHoursInMinutes }
    }

    public var weeklyWindow: QuotaWindow? {
        windows.first { $0.durationMinutes == QuotaConstants.oneWeekInMinutes }
    }

    public var nextResetAt: Date? {
        windows.compactMap(\.resetsAt).filter { $0 > .now }.min()
    }

    public func isStale(
        at now: Date = .now,
        interval: TimeInterval = QuotaConstants.staleAfter
    ) -> Bool {
        now.timeIntervalSince(fetchedAt) > interval
    }

    public func withFailure(
        status: SyncStatus,
        message: String?
    ) -> QuotaSnapshot {
        var copy = self
        copy.status = status
        copy.statusMessage = message
        return copy
    }
}

public enum TokenScale: Sendable, Equatable {
    case tokens
    case thousands
    case millions

    public var divisor: Double {
        switch self {
        case .tokens: 1
        case .thousands: 1_000
        case .millions: 1_000_000
        }
    }

    public var suffix: String {
        switch self {
        case .tokens: ""
        case .thousands: "K"
        case .millions: "M"
        }
    }

    public static func best(for points: [DailyUsagePoint]) -> TokenScale {
        let maximum = points.map(\.tokens).max() ?? 0
        if maximum >= 1_000_000 { return .millions }
        if maximum >= 1_000 { return .thousands }
        return .tokens
    }
}
