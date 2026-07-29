import Foundation
import QuotaCore

@main
struct QuotaProbe {
    static func main() async {
        let service = CodexQuotaService()
        do {
            try await service.start(
                customPath: ProcessInfo.processInfo.environment["QUOTA_CODEX_PATH"]
            )
            let snapshot = try await service.fetchSnapshot(
                includeUsage: true,
                previous: nil
            )
            let windows = snapshot.windows.map {
                "\($0.displayLabel)=\($0.remainingPercent)%"
            }.joined(separator: ", ")
            print("status=\(snapshot.status.rawValue)")
            print("windows=\(windows.isEmpty ? "none" : windows)")
            print("dailyPoints=\(snapshot.dailyUsage.count)")
            await service.stop()
        } catch {
            fputs("QuotaProbe failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
