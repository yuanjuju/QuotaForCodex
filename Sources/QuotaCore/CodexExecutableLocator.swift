import Foundation

public enum CodexExecutableLocator {
    public enum LocatorError: Error, LocalizedError, Sendable {
        case notInstalled
        case notExecutable(String)
        case versionCheckFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notInstalled:
                "未找到可用的 Codex 应用或命令行工具"
            case let .notExecutable(path):
                "Codex 路径不可执行：\(path)"
            case let .versionCheckFailed(message):
                "无法读取 Codex 版本：\(message)"
            }
        }
    }

    public static func locate(
        customPath: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> URL {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let candidates = candidatePaths(
            customPath: customPath,
            home: home,
            environment: environment
        )

        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate).inserted {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: candidate, isDirectory: &isDirectory),
                  !isDirectory.boolValue
            else {
                continue
            }
            guard fileManager.isExecutableFile(atPath: candidate) else {
                if candidate == customPath {
                    throw LocatorError.notExecutable(candidate)
                }
                continue
            }
            return URL(fileURLWithPath: candidate)
        }

        throw LocatorError.notInstalled
    }

    static func candidatePaths(
        customPath: String?,
        home: String,
        environment: [String: String]
    ) -> [String] {
        var candidates: [String] = []
        if let customPath, !customPath.trimmingCharacters(in: .whitespaces).isEmpty {
            candidates.append(customPath)
        }

        let applicationRoots = ["/Applications", "\(home)/Applications"]
        let applicationNames = ["ChatGPT.app", "Codex.app"]
        for root in applicationRoots {
            for applicationName in applicationNames {
                let resources = "\(root)/\(applicationName)/Contents/Resources"
                candidates.append("\(resources)/codex-cli/bin/codex")
                candidates.append("\(resources)/codex-cli/CodexCLI.app/Contents/MacOS/codex")
                candidates.append("\(resources)/codex")
            }
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ])

        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map {
                URL(fileURLWithPath: String($0))
                    .appendingPathComponent("codex")
                    .path
            })
        }
        return candidates
    }

    public static func version(at executableURL: URL) throws -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executableURL
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw LocatorError.versionCheckFailed(error.localizedDescription)
        }

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if process.terminationStatus == 0, let text, !text.isEmpty {
            return text
        }

        let message = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        throw LocatorError.versionCheckFailed(message ?? "exit \(process.terminationStatus)")
    }
}
