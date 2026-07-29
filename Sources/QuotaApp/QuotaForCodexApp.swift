import AppKit
import QuotaCore
import SwiftUI

@main
struct QuotaForCodexApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            Label {
                if let remaining = model.snapshot.weeklyWindow?.remainingPercent {
                    Text("\(remaining)%")
                } else {
                    Text("Codex")
                }
            } icon: {
                Image(systemName: "gauge.with.dots.needle.67percent")
            }
            .accessibilityLabel("Quota for Codex")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
