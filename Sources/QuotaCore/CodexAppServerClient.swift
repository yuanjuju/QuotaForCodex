import Foundation

public actor CodexAppServerClient {
    public enum ClientError: Error, LocalizedError, Sendable {
        case processNotRunning
        case processExited
        case requestTimedOut(String)
        case invalidResponse
        case writeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .processNotRunning:
                "Codex app-server 未运行"
            case .processExited:
                "Codex app-server 已退出"
            case let .requestTimedOut(method):
                "Codex 请求超时：\(method)"
            case .invalidResponse:
                "Codex 返回了无法识别的数据"
            case let .writeFailed(message):
                "无法向 Codex 发送请求：\(message)"
            }
        }
    }

    private let executableURL: URL
    private let requestTimeout: Duration
    private let initializationTimeout: Duration
    private let diagnosticsEnabled: Bool
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var outputTask: Task<Void, Never>?
    private var errorTask: Task<Void, Never>?
    private var nextRequestID = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var eventContinuations: [UUID: AsyncStream<CodexEvent>.Continuation] = [:]
    private var connected = false

    public private(set) var serverUserAgent: String?

    public init(
        executableURL: URL,
        requestTimeout: Duration = .seconds(15),
        initializationTimeout: Duration? = nil,
        diagnosticsEnabled: Bool = ProcessInfo.processInfo.environment["QUOTA_CODEX_DEBUG"] == "1"
    ) {
        self.executableURL = executableURL
        self.requestTimeout = requestTimeout
        self.initializationTimeout = initializationTimeout ?? requestTimeout
        self.diagnosticsEnabled = diagnosticsEnabled
    }

    public func events() -> AsyncStream<CodexEvent> {
        let identifier = UUID()
        return AsyncStream { continuation in
            eventContinuations[identifier] = continuation
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeEventContinuation(identifier)
                }
            }
        }
    }

    public func connect() async throws {
        if connected, process?.isRunning == true { return }
        await disconnect()

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw ClientError.writeFailed(error.localizedDescription)
        }

        self.process = process
        inputPipe = input
        outputPipe = output
        errorPipe = errors
        startReaders(
            outputHandle: output.fileHandleForReading,
            errorHandle: errors.fileHandleForReading
        )

        do {
            let response: InitializeResponse = try await request(
                method: "initialize",
                params: InitializeParams(
                    clientInfo: .init(
                        name: "quota-for-codex",
                        title: "Quota for Codex",
                        version: "0.1.0"
                    ),
                    capabilities: .init(experimentalApi: true)
                ),
                response: InitializeResponse.self,
                timeout: initializationTimeout
            )
            // The app-server acknowledges initialize before all connection state is
            // necessarily visible to following requests. A short hand-off avoids
            // racing the required `initialized` notification on fast local machines.
            try await Task.sleep(for: .seconds(1))
            try sendNotification(method: "initialized", params: Optional<NullParams>.none)
            try await Task.sleep(for: .milliseconds(25))
            serverUserAgent = response.userAgent
            connected = true
            publish(.connected(userAgent: response.userAgent))
        } catch {
            await disconnect()
            throw error
        }
    }

    public func readRateLimits() async throws -> RateLimitsReadResponse {
        try await ensureConnected()
        return try await request(
            method: "account/rateLimits/read",
            params: NullParams(),
            response: RateLimitsReadResponse.self
        )
    }

    public func readUsage() async throws -> AccountUsageReadResponse {
        try await ensureConnected()
        return try await request(
            method: "account/usage/read",
            params: NullParams(),
            response: AccountUsageReadResponse.self
        )
    }

    public func disconnect() async {
        connected = false
        outputTask?.cancel()
        errorTask?.cancel()
        outputTask = nil
        errorTask = nil

        let error = ClientError.processExited
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: error) }

        try? inputPipe?.fileHandleForWriting.close()
        try? outputPipe?.fileHandleForReading.close()
        try? errorPipe?.fileHandleForReading.close()

        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
    }

    private func ensureConnected() async throws {
        if !connected || process?.isRunning != true {
            try await connect()
        }
    }

    private func request<Params: Encodable & Sendable, Response: Decodable>(
        method: String,
        params: Params,
        response: Response.Type,
        timeout: Duration? = nil
    ) async throws -> Response {
        let requestID = nextRequestID
        nextRequestID += 1
        diagnostic("send id=\(requestID) method=\(method)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let payload = try encoder.encode(
            RPCRequest(id: requestID, method: method, params: params)
        )
        if diagnosticsEnabled, let text = String(data: payload, encoding: .utf8) {
            diagnostic("request payload=\(text)")
        }

        let data: Data = try await withCheckedThrowingContinuation { continuation in
            pending[requestID] = continuation
            do {
                try writeLine(payload)
            } catch {
                pending.removeValue(forKey: requestID)
                continuation.resume(throwing: error)
                return
            }

            let effectiveTimeout = timeout ?? requestTimeout
            Task { [weak self, effectiveTimeout] in
                try? await Task.sleep(for: effectiveTimeout)
                await self?.timeout(requestID: requestID, method: method)
            }
        }

        do {
            return try JSONDecoder().decode(response, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
    }

    private func sendNotification<Params: Encodable>(
        method: String,
        params: Params?
    ) throws {
        diagnostic("send notification method=\(method)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let payload = try encoder.encode(
            RPCNotification(method: method, params: params)
        )
        if diagnosticsEnabled, let text = String(data: payload, encoding: .utf8) {
            diagnostic("notification payload=\(text)")
        }
        try writeLine(payload)
    }

    private func writeLine(_ payload: Data) throws {
        guard process?.isRunning == true,
              let handle = inputPipe?.fileHandleForWriting
        else {
            throw ClientError.processNotRunning
        }
        var line = payload
        line.append(0x0A)
        do {
            try handle.write(contentsOf: line)
        } catch {
            throw ClientError.writeFailed(error.localizedDescription)
        }
    }

    private func startReaders(
        outputHandle: FileHandle,
        errorHandle: FileHandle
    ) {
        outputTask = Task.detached(priority: .utility) { [weak self] in
            var buffer = Data()
            while !Task.isCancelled {
                let chunk = outputHandle.availableData
                guard !chunk.isEmpty else { break }
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let line = Data(buffer[..<newline])
                    buffer.removeSubrange(...newline)
                    if !line.isEmpty {
                        await self?.receive(line: line)
                    }
                }
            }
            await self?.handleProcessExit()
        }

        errorTask = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                let chunk = errorHandle.availableData
                guard !chunk.isEmpty else { break }
            }
        }
    }

    private func receive(line: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            diagnostic("receive invalid-json")
            return
        }
        let receivedID = (object["id"] as? NSNumber)?.intValue
        let receivedMethod = object["method"] as? String
        diagnostic("receive id=\(receivedID.map(String.init) ?? "-") method=\(receivedMethod ?? "-")")

        if let identifier = receivedID,
           let continuation = pending.removeValue(forKey: identifier) {
            if let errorObject = object["error"] {
                let errorData = try? JSONSerialization.data(
                    withJSONObject: errorObject,
                    options: [.fragmentsAllowed]
                )
                let remoteError = errorData.flatMap {
                    try? JSONDecoder().decode(RPCRemoteError.self, from: $0)
                } ?? RPCRemoteError(code: nil, message: "Codex request failed")
                continuation.resume(throwing: remoteError)
                return
            }

            guard let result = object["result"],
                  let resultData = try? JSONSerialization.data(
                    withJSONObject: result,
                    options: [.fragmentsAllowed]
                  )
            else {
                continuation.resume(throwing: ClientError.invalidResponse)
                return
            }
            continuation.resume(returning: resultData)
            return
        }

        if object["method"] as? String == "account/rateLimits/updated" {
            publish(.rateLimitsChanged)
        }
    }

    private func timeout(requestID: Int, method: String) {
        guard let continuation = pending.removeValue(forKey: requestID) else { return }
        continuation.resume(throwing: ClientError.requestTimedOut(method))
    }

    private func handleProcessExit() {
        guard process != nil else { return }
        connected = false
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: ClientError.processExited) }
        publish(.disconnected(reason: "Codex app-server 已退出"))
        process = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
    }

    private func publish(_ event: CodexEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    private func removeEventContinuation(_ identifier: UUID) {
        eventContinuations.removeValue(forKey: identifier)
    }

    private func diagnostic(_ message: String) {
        guard diagnosticsEnabled,
              let data = "[QuotaCodexRPC] \(message)\n".data(using: .utf8)
        else {
            return
        }
        try? FileHandle.standardError.write(contentsOf: data)
    }
}
