import QuotaCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("连接") {
                LabeledContent("状态") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.snapshot.status == .ready ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(model.snapshot.statusMessage ?? model.snapshot.status.defaultMessage)
                    }
                }

                LabeledContent("Codex 路径") {
                    Text(model.detectedExecutablePath ?? "尚未检测")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                HStack {
                    Button("选择可执行文件…") {
                        model.chooseExecutable()
                    }
                    if model.customExecutablePath != nil {
                        Button("恢复自动检测") {
                            model.clearCustomExecutable()
                        }
                    }
                    Spacer()
                    Button("测试连接") {
                        Task { await model.refreshNow(forceUsage: true) }
                    }
                    .disabled(model.isRefreshing)
                }
            }

            Section("后台更新") {
                Toggle(
                    "登录时启动 Quota for Codex",
                    isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                Text("菜单栏应用每 60 秒检查额度；最近 7 天趋势每 15 分钟更新。Widget 的实际刷新时间由 macOS 控制。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = model.storeMessage {
                Section("诊断") {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Text("Quota for Codex 是独立第三方工具，不隶属于 OpenAI。应用不会读取或保存 Codex 登录凭证。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 390)
        .padding()
    }
}
