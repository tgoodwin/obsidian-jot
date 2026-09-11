import Foundation

actor CodexAppServerClient: LLMClient {
    private var process: Process?
    private var inputHandle: FileHandle?
    private var readerTask: Task<Void, Never>?
    private var executablePath: String?
    private var nextRequestID = 1
    private var pendingRequests: [Int: CheckedContinuation<[String: Any], Error>] = [:]

    private var threadID: String?
    private var activeThreadID: String?
    private var activeResponse = ""
    private var completedTurn: Result<String, Error>?
    private var turnContinuation: CheckedContinuation<String, Error>?

    func complete(messages: [ChatMessage], configuration: LLMConfiguration) async throws -> String {
        try await ensureStarted(executablePath: configuration.codexExecutablePath)
        let threadID = try await ensureThread(model: configuration.model)
        guard let prompt = messages.last(where: { $0.role == .user })?.content else {
            throw LLMClientError.emptyResponse
        }

        activeThreadID = threadID
        activeResponse = ""
        completedTurn = nil

        _ = try await sendRequest(
            method: "turn/start",
            params: [
                "threadId": threadID,
                "input": [["type": "text", "text": prompt]]
            ]
        )
        return try await waitForTurnCompletion()
    }

    func resetThread() async {
        guard let threadID else { return }
        self.threadID = nil
        activeThreadID = nil
        activeResponse = ""
        completedTurn = nil
        turnContinuation?.resume(throwing: CancellationError())
        turnContinuation = nil
        _ = try? await sendRequest(
            method: "thread/unsubscribe",
            params: ["threadId": threadID]
        )
    }

    private func ensureStarted(executablePath requestedPath: String) async throws {
        let path = requestedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
            throw LLMClientError.codexNotFound(path)
        }
        if process?.isRunning == true, executablePath == path {
            return
        }

        stopProcess()

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw LLMClientError.codexLaunchFailed(error.localizedDescription)
        }

        self.process = process
        executablePath = path
        inputHandle = inputPipe.fileHandleForWriting
        let outputHandle = outputPipe.fileHandleForReading
        readerTask = Task { [weak self] in
            do {
                for try await line in outputHandle.bytes.lines {
                    await self?.receive(line: line)
                }
                await self?.serverStopped()
            } catch {
                await self?.serverStopped(error: error)
            }
        }

        _ = try await sendRequest(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "obsidian_jot",
                    "title": "Obsidian Jot",
                    "version": "0.1.0"
                ]
            ]
        )
        try sendNotification(method: "initialized", params: [:])
    }

    private func ensureThread(model: String) async throws -> String {
        if let threadID { return threadID }

        var params: [String: Any] = [
            "cwd": FileManager.default.temporaryDirectory.path,
            "approvalPolicy": "never",
            "sandbox": "read-only",
            "ephemeral": true,
            "serviceName": "obsidian_jot",
            "baseInstructions": """
                You are a concise, helpful general-purpose assistant in a quick-chat window.
                Answer questions directly. Do not inspect files, run commands, or modify the computer.
                """
        ]
        let selectedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selectedModel.isEmpty {
            params["model"] = selectedModel
        }

        let response = try await sendRequest(method: "thread/start", params: params)
        guard let result = response["result"] as? [String: Any],
              let thread = result["thread"] as? [String: Any],
              let id = thread["id"] as? String else {
            throw LLMClientError.invalidResponse
        }
        threadID = id
        return id
    }

    private func waitForTurnCompletion() async throws -> String {
        if let completedTurn {
            self.completedTurn = nil
            return try completedTurn.get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            turnContinuation = continuation
        }
    }

    private func sendRequest(method: String, params: [String: Any]) async throws -> [String: Any] {
        let id = nextRequestID
        nextRequestID += 1
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = continuation
            do {
                try writeJSON(["method": method, "id": id, "params": params])
            } catch {
                pendingRequests.removeValue(forKey: id)
                continuation.resume(throwing: error)
            }
        }
    }

    private func sendNotification(method: String, params: [String: Any]) throws {
        try writeJSON(["method": method, "params": params])
    }

    private func writeJSON(_ object: [String: Any]) throws {
        guard let inputHandle, process?.isRunning == true else {
            throw LLMClientError.codexLaunchFailed("The app-server process is not running.")
        }
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try inputHandle.write(contentsOf: data)
    }

    private func receive(line: String) {
        guard let data = line.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let id = message["id"] as? Int, let continuation = pendingRequests.removeValue(forKey: id) {
            if let error = message["error"] as? [String: Any] {
                continuation.resume(throwing: AppServerError.message(error["message"] as? String ?? "Codex request failed."))
            } else {
                continuation.resume(returning: message)
            }
            return
        }

        guard let method = message["method"] as? String,
              let params = message["params"] as? [String: Any] else {
            return
        }

        switch method {
        case "item/agentMessage/delta":
            guard params["threadId"] as? String == activeThreadID,
                  let delta = params["delta"] as? String else { return }
            activeResponse += delta

        case "item/completed":
            guard params["threadId"] as? String == activeThreadID,
                  activeResponse.isEmpty,
                  let item = params["item"] as? [String: Any],
                  item["type"] as? String == "agentMessage",
                  let text = item["text"] as? String else { return }
            activeResponse = text

        case "turn/completed":
            guard params["threadId"] as? String == activeThreadID else { return }
            let turn = params["turn"] as? [String: Any]
            let status = turn?["status"] as? String
            if status == "completed", !activeResponse.isEmpty {
                finishTurn(.success(activeResponse))
            } else {
                let error = turn?["error"] as? [String: Any]
                let message = error?["message"] as? String ?? "Codex did not complete the response."
                finishTurn(.failure(AppServerError.message(message)))
            }

        default:
            break
        }
    }

    private func finishTurn(_ result: Result<String, Error>) {
        activeThreadID = nil
        activeResponse = ""
        if let continuation = turnContinuation {
            turnContinuation = nil
            continuation.resume(with: result)
        } else {
            completedTurn = result
        }
    }

    private func serverStopped(error: Error? = nil) {
        let failure = error ?? AppServerError.message("Codex app-server stopped unexpectedly.")
        for continuation in pendingRequests.values {
            continuation.resume(throwing: failure)
        }
        pendingRequests.removeAll()
        turnContinuation?.resume(throwing: failure)
        turnContinuation = nil
        process = nil
        inputHandle = nil
        executablePath = nil
        threadID = nil
    }

    private func stopProcess() {
        readerTask?.cancel()
        readerTask = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        try? inputHandle?.close()
        inputHandle = nil
        executablePath = nil
        threadID = nil
    }
}

private enum AppServerError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(message): message
        }
    }
}
