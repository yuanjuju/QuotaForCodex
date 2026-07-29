import AppKit
import Combine
import Foundation
import QuotaCore
import ServiceManagement
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: QuotaSnapshot
    @Published private(set) var isRefreshing = false
    @Published private(set) var detectedExecutablePath: String?
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var storeMessage: String?

    private let service = CodexQuotaService()
    private let store: SnapshotStore?
    private var refreshLoopTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var wakeTask: Task<Void, Never>?
    private var failureCount = 0
    private var lastUsageRefresh: Date?

    private static let customPathKey = "codexExecutablePath"
    private static let reconnectDelays: [UInt64] = [1, 2, 5, 15, 60]

    var customExecutablePath: String? {
        UserDefaults.standard.string(forKey: Self.customPathKey)
    }

    init() {
        let resolvedStore: SnapshotStore?
        do {
            resolvedStore = try SnapshotStore.shared()
        } catch {
            resolvedStore = nil
            storeMessage = error.localizedDescription
        }
        store = resolvedStore
        snapshot = (try? resolvedStore?.load()) ?? .empty()
        refreshLaunchAtLoginStatus()

        Task { [weak self] in
            self?.start()
        }
    }

    func start() {
        guard refreshLoopTask == nil else { return }
        observeWake()
        refreshLoopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let success = await self.refreshNow()
                let delay: UInt64
                if success {
                    delay = 60
                } else {
                    let index = min(self.failureCount, Self.reconnectDelays.count - 1)
                    delay = Self.reconnectDelays[index]
                }
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    @discardableResult
    func refreshNow(forceUsage: Bool = false) async -> Bool {
        guard !isRefreshing else { return snapshot.status == .ready }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await ensureServiceStarted()
            let shouldFetchUsage = forceUsage
                || lastUsageRefresh == nil
                || Date.now.timeIntervalSince(lastUsageRefresh ?? .distantPast) >= 15 * 60
            let previous = snapshot
            let refreshed = try await service.fetchSnapshot(
                includeUsage: shouldFetchUsage,
                previous: previous
            )
            if shouldFetchUsage {
                lastUsageRefresh = .now
            }
            snapshot = refreshed
            failureCount = 0
            detectedExecutablePath = await service.currentExecutablePath()
            persistAndReloadIfChanged(previous: previous)
            return true
        } catch {
            failureCount += 1
            await service.stop()
            eventTask?.cancel()
            eventTask = nil

            let mapped = map(error: error)
            if snapshot.windows.isEmpty && snapshot.dailyUsage.isEmpty {
                snapshot = .empty(status: mapped.status, message: mapped.message)
            } else {
                let status: SyncStatus = snapshot.isStale() ? .stale : mapped.status
                snapshot = snapshot.withFailure(status: status, message: mapped.message)
            }
            try? store?.save(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: QuotaConstants.widgetKind)
            return false
        }
    }

    func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.title = "选择 Codex 可执行文件"
        panel.message = "请选择 Codex、ChatGPT 应用内置的 codex，或独立 Codex CLI。"
        panel.prompt = "使用此文件"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: Self.customPathKey)
        Task {
            await reconnectForPathChange()
        }
    }

    func clearCustomExecutable() {
        UserDefaults.standard.removeObject(forKey: Self.customPathKey)
        Task {
            await reconnectForPathChange()
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLaunchAtLoginStatus()
        } catch {
            storeMessage = "无法修改登录项：\(error.localizedDescription)"
            refreshLaunchAtLoginStatus()
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    private func reconnectForPathChange() async {
        eventTask?.cancel()
        eventTask = nil
        await service.stop()
        detectedExecutablePath = nil
        _ = await refreshNow(forceUsage: true)
    }

    private func ensureServiceStarted() async throws {
        if await service.currentExecutablePath() == nil {
            try await service.start(customPath: customExecutablePath)
            detectedExecutablePath = await service.currentExecutablePath()
            await startEventListener()
        }
    }

    private func startEventListener() async {
        guard eventTask == nil, let stream = try? await service.events() else { return }
        eventTask = Task { [weak self] in
            for await event in stream {
                guard let self, !Task.isCancelled else { return }
                switch event {
                case .rateLimitsChanged:
                    _ = await self.refreshNow()
                case .disconnected:
                    self.failureCount += 1
                case .connected:
                    break
                }
            }
        }
    }

    private func observeWake() {
        guard wakeTask == nil else { return }
        wakeTask = Task { [weak self] in
            let notifications = NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.didWakeNotification
            )
            for await _ in notifications {
                guard let self, !Task.isCancelled else { return }
                _ = await self.refreshNow(forceUsage: true)
            }
        }
    }

    private func persistAndReloadIfChanged(previous: QuotaSnapshot) {
        do {
            try store?.save(snapshot)
            storeMessage = nil
        } catch {
            storeMessage = error.localizedDescription
        }

        if previous.windows != snapshot.windows
            || previous.dailyUsage != snapshot.dailyUsage
            || previous.status != snapshot.status {
            WidgetCenter.shared.reloadTimelines(ofKind: QuotaConstants.widgetKind)
        }
    }

    private func map(error: Error) -> (status: SyncStatus, message: String) {
        if let locatorError = error as? CodexExecutableLocator.LocatorError {
            switch locatorError {
            case .notInstalled, .notExecutable:
                return (.notInstalled, locatorError.localizedDescription)
            case .versionCheckFailed:
                return (.incompatible, locatorError.localizedDescription)
            }
        }

        let message = error.localizedDescription
        let normalized = message.lowercased()
        if normalized.contains("login")
            || normalized.contains("auth")
            || normalized.contains("401")
            || normalized.contains("unauthorized") {
            return (.notLoggedIn, "请先在 Codex 中登录后再刷新")
        }
        if normalized.contains("method not found")
            || normalized.contains("invalid request")
            || normalized.contains("unsupported") {
            return (.incompatible, "当前 Codex 版本不支持额度读取")
        }
        if normalized.contains("network")
            || normalized.contains("offline")
            || normalized.contains("connection") {
            return (.offline, message)
        }
        return (.failed, message)
    }
}
