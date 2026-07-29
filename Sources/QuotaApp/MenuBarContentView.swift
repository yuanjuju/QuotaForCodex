import AppKit
import QuotaCore
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Quota for Codex", systemImage: "terminal.fill")
                    .font(.headline)
                Spacer()
                if model.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            QuotaMenuRow(title: "5h", window: model.snapshot.fiveHourWindow)
            QuotaMenuRow(title: "Week", window: model.snapshot.weeklyWindow)

            if model.snapshot.status != .ready {
                Label(
                    model.snapshot.statusMessage ?? model.snapshot.status.defaultMessage,
                    systemImage: statusIcon
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("最后更新")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(model.snapshot.fetchedAt, style: .time)
                        .font(.caption)
                }
                Spacer()
                Button {
                    Task { await model.refreshNow(forceUsage: true) }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(model.isRefreshing)
            }

            HStack {
                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                }
                Spacer()
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var statusIcon: String {
        switch model.snapshot.status {
        case .ready:
            "checkmark.circle"
        case .loading:
            "hourglass"
        case .stale:
            "clock.badge.exclamationmark"
        default:
            "exclamationmark.triangle"
        }
    }
}

private struct QuotaMenuRow: View {
    let title: String
    let window: QuotaWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                if let window {
                    Text("\(window.remainingPercent)%")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: Double(window?.remainingPercent ?? 0), total: 100)
                .tint(quotaColor)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                if let reset = window?.resetsAt {
                    Text("重置于 \(reset.formatted(date: .abbreviated, time: .shortened))")
                } else {
                    Text("暂无数据")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var quotaColor: Color {
        guard let remaining = window?.remainingPercent else { return .secondary }
        if remaining >= 50 { return .green }
        if remaining >= 20 { return .orange }
        return .red
    }
}
