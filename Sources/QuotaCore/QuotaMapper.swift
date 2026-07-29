import Foundation

public enum QuotaMapper {
    public static func windows(from response: RateLimitsReadResponse) -> [QuotaWindow] {
        let selected = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits
        let limitID = selected.limitId ?? "codex"

        let payloads: [(String, RateLimitWindowPayload?)] = [
            ("primary", selected.primary),
            ("secondary", selected.secondary)
        ]

        return payloads.compactMap { position, payload in
            guard let payload else { return nil }
            let resetDate = payload.resetsAt.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            }
            let durationPart = payload.windowDurationMins.map(String.init) ?? "unknown"
            return QuotaWindow(
                id: "\(limitID)-\(durationPart)-\(position)",
                durationMinutes: payload.windowDurationMins,
                usedPercent: payload.usedPercent,
                resetsAt: resetDate
            )
        }
        .sorted {
            ($0.durationMinutes ?? .max) < ($1.durationMinutes ?? .max)
        }
    }

    public static func lastSevenDays(
        from buckets: [AccountUsageDailyBucket],
        now: Date = .now,
        calendar inputCalendar: Calendar = .current
    ) -> [DailyUsagePoint] {
        let calendar = inputCalendar
        let locale = Locale(identifier: "en_US_POSIX")
        var totals: [String: Int64] = [:]
        for bucket in buckets {
            totals[bucket.startDate, default: 0] += max(bucket.tokens, 0)
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        let today = calendar.startOfDay(for: now)
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let key = formatter.string(from: date)
            return DailyUsagePoint(date: key, tokens: totals[key, default: 0])
        }
    }

    public static func snapshot(
        rateLimits: RateLimitsReadResponse,
        usage: AccountUsageReadResponse?,
        previous: QuotaSnapshot? = nil,
        sourceVersion: String?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> QuotaSnapshot {
        let usagePoints: [DailyUsagePoint]
        if let buckets = usage?.dailyUsageBuckets {
            usagePoints = lastSevenDays(from: buckets, now: now, calendar: calendar)
        } else if let previous {
            usagePoints = previous.dailyUsage
        } else {
            usagePoints = lastSevenDays(from: [], now: now, calendar: calendar)
        }

        return QuotaSnapshot(
            fetchedAt: now,
            sourceVersion: sourceVersion,
            windows: windows(from: rateLimits),
            dailyUsage: usagePoints,
            status: .ready
        )
    }
}
