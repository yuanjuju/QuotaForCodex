import Charts
import QuotaCore
import SwiftUI
import WidgetKit

struct QuotaWidgetRootView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuotaWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumQuotaWidgetView(snapshot: entry.snapshot)
            default:
                SmallQuotaWidgetView(snapshot: entry.snapshot)
            }
        }
        .padding(14)
    }
}

private struct SmallQuotaWidgetView: View {
    let snapshot: QuotaSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(status: snapshot.status)
            WidgetQuotaRow(title: "5h", window: snapshot.fiveHourWindow)
            WidgetQuotaRow(title: "Week", window: snapshot.weeklyWindow)
            Spacer(minLength: 0)
            statusFooter
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        if snapshot.status != .ready {
            Text(snapshot.statusMessage ?? snapshot.status.defaultMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct MediumQuotaWidgetView: View {
    let snapshot: QuotaSnapshot

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                WidgetHeader(status: snapshot.status)
                WidgetQuotaRow(title: "5h", window: snapshot.fiveHourWindow)
                WidgetQuotaRow(title: "Week", window: snapshot.weeklyWindow)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            Divider()

            UsageChart(points: snapshot.dailyUsage)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct WidgetHeader: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "terminal.fill")
                .font(.title3)
                .widgetAccentable()
            Text("Codex")
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 2)
            if status == .stale {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WidgetQuotaRow: View {
    let title: String
    let window: QuotaWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(window.map { "\($0.remainingPercent)%" } ?? "—")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(window == nil ? .secondary : .primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.18))
                    Capsule()
                        .fill(quotaColor)
                        .frame(
                            width: proxy.size.width
                                * CGFloat(window?.remainingPercent ?? 0)
                                / 100
                        )
                        .widgetAccentable()
                }
            }
            .frame(height: 5)

            HStack(spacing: 3) {
                Image(systemName: "clock")
                if let reset = window?.resetsAt {
                    Text(reset, format: .dateTime.month(.twoDigits).day(.twoDigits).hour().minute())
                } else {
                    Text("暂无数据")
                }
            }
            .font(.system(size: 8))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let window else { return "\(title) 暂无数据" }
        return "\(title) 剩余 \(window.remainingPercent)%"
    }

    private var quotaColor: Color {
        guard let remaining = window?.remainingPercent else { return .secondary }
        if remaining >= 50 { return .green }
        if remaining >= 20 { return .orange }
        return .red
    }
}

private struct UsageChart: View {
    let points: [DailyUsagePoint]

    private var scale: TokenScale {
        TokenScale.best(for: points)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("近 7 天趋势")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("单位 \(scale.suffix.isEmpty ? "tokens" : scale.suffix)")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }

            Chart(points) { point in
                BarMark(
                    x: .value("日期", dayLabel(point.date)),
                    y: .value("Token", Double(point.tokens) / scale.divisor)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(2)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.system(size: 7))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 7))
                }
            }
            .chartYScale(domain: 0...(maximumChartValue))
            .widgetAccentable()
        }
    }

    private var maximumChartValue: Double {
        max(
            points.map { Double($0.tokens) / scale.divisor }.max() ?? 0,
            1
        )
    }

    private func dayLabel(_ value: String) -> String {
        guard let day = value.split(separator: "-").last else { return value }
        return Int(day).map(String.init) ?? String(day)
    }
}
