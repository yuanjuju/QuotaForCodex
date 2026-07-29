import QuotaCore
import SwiftUI
import WidgetKit

struct QuotaWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: QuotaSnapshot
}

struct QuotaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuotaWidgetEntry {
        QuotaWidgetEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (QuotaWidgetEntry) -> Void
    ) {
        if context.isPreview {
            completion(QuotaWidgetEntry(date: .now, snapshot: .preview))
        } else {
            completion(QuotaWidgetEntry(date: .now, snapshot: loadSnapshot()))
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<QuotaWidgetEntry>) -> Void
    ) {
        let now = Date.now
        var snapshot = loadSnapshot()
        if snapshot.status == .ready, snapshot.isStale(at: now) {
            snapshot.status = .stale
            snapshot.statusMessage = SyncStatus.stale.defaultMessage
        }

        var refreshDate = now.addingTimeInterval(15 * 60)
        if let reset = snapshot.windows
            .compactMap(\.resetsAt)
            .filter({ $0 > now })
            .min() {
            refreshDate = min(refreshDate, reset.addingTimeInterval(60))
        }

        let entry = QuotaWidgetEntry(date: now, snapshot: snapshot)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadSnapshot() -> QuotaSnapshot {
        guard let store = try? SnapshotStore.shared(),
              let snapshot = try? store.load()
        else {
            return .empty(
                status: .notInstalled,
                message: "打开 Quota for Codex 完成设置"
            )
        }
        return snapshot
    }
}

struct QuotaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: QuotaConstants.widgetKind,
            provider: QuotaTimelineProvider()
        ) { entry in
            QuotaWidgetRootView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quota for Codex")
        .description("显示 Codex 剩余额度与最近 7 天用量。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private extension QuotaSnapshot {
    static var preview: QuotaSnapshot {
        let now = Date.now
        return QuotaSnapshot(
            fetchedAt: now,
            sourceVersion: "codex-cli preview",
            windows: [
                QuotaWindow(
                    id: "preview-5h",
                    durationMinutes: 300,
                    usedPercent: 1,
                    resetsAt: now.addingTimeInterval(3 * 60 * 60)
                ),
                QuotaWindow(
                    id: "preview-week",
                    durationMinutes: 10_080,
                    usedPercent: 81,
                    resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60)
                )
            ],
            dailyUsage: [
                .init(date: "07-23", tokens: 21_000_000),
                .init(date: "07-24", tokens: 35_000_000),
                .init(date: "07-25", tokens: 72_000_000),
                .init(date: "07-26", tokens: 28_000_000),
                .init(date: "07-27", tokens: 44_000_000),
                .init(date: "07-28", tokens: 17_000_000),
                .init(date: "07-29", tokens: 18_000_000)
            ],
            status: .ready
        )
    }
}
