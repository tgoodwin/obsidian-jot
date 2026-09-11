import Foundation

struct LLMConfiguration {
    let baseURL: String
    let model: String
    let apiKey: String
    let codexExecutablePath: String
}

protocol LLMClient {
    func complete(messages: [ChatMessage], configuration: LLMConfiguration) async throws -> String
}

struct CodexCLIClient: LLMClient {
    func complete(messages: [ChatMessage], configuration: LLMConfiguration) async throws -> String {
        let prompt = conversationPrompt(messages)
        return try await Task.detached(priority: .userInitiated) {
            try runCodex(prompt: prompt, configuration: configuration)
        }.value
    }

    private func conversationPrompt(_ messages: [ChatMessage]) -> String {
        let transcript = messages.map { message in
            let speaker = message.role == .user ? "User" : "Assistant"
            return "\(speaker):\n\(message.content)"
        }.joined(separator: "\n\n")

        return """
        You are a concise, helpful general-purpose assistant in a quick-chat window.
        Answer the user's latest message directly. Use the preceding transcript only as conversation context.
        Do not inspect files, run shell commands, or modify the computer.

        \(transcript)

        Assistant:
        """
    }

    private func runCodex(prompt: String, configuration: LLMConfiguration) throws -> String {
        let executablePath = configuration.codexExecutablePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !executablePath.isEmpty,
              FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw LLMClientError.codexNotFound(executablePath)
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ObsidianJot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let outputURL = temporaryDirectory.appendingPathComponent("stdout.txt")
        let errorURL = temporaryDirectory.appendingPathComponent("stderr.txt")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)

        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.currentDirectoryURL = temporaryDirectory
        var arguments = [
            "exec",
            "--ephemeral",
            "--skip-git-repo-check",
            "--sandbox", "read-only",
            "--ignore-user-config",
            "--ignore-rules",
            "--color", "never"
        ]
        if !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments += ["--model", configuration.model]
        }
        arguments.append("-")
        process.arguments = arguments
        process.standardOutput = outputHandle
        process.standardError = errorHandle

        let inputPipe = Pipe()
        process.standardInput = inputPipe

        do {
            try process.run()
            inputPipe.fileHandleForWriting.write(Data(prompt.utf8))
            try inputPipe.fileHandleForWriting.close()
            process.waitUntilExit()
        } catch {
            throw LLMClientError.codexLaunchFailed(error.localizedDescription)
        }

        let output = (try? String(contentsOf: outputURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = (try? String(contentsOf: errorURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw LLMClientError.codexFailed(
                status: process.terminationStatus,
                message: errorOutput
            )
        }
        guard !output.isEmpty else {
            throw LLMClientError.emptyResponse
        }
        return output
    }
}

struct OpenAICompatibleClient: LLMClient {
    func complete(messages: [ChatMessage], configuration: LLMConfiguration) async throws -> String {
        guard let endpoint = endpointURL(from: configuration.baseURL) else {
            throw LLMClientError.invalidBaseURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !configuration.apiKey.isEmpty {
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let requestBody = CompletionRequest(
            model: configuration.model,
            messages: messages.map { APIMessage(role: $0.role.rawValue, content: $0.content) }
        )
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw LLMClientError.requestFailed(
                status: httpResponse.statusCode,
                message: apiError?.error.message
            )
        }

        let completion = try JSONDecoder().decode(CompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content, !content.isEmpty else {
            throw LLMClientError.emptyResponse
        }
        return content
    }

    private func endpointURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed), components.scheme != nil else {
            return nil
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("chat/completions") {
            return components.url
        }
        components.path = "/" + [path, "chat/completions"].filter { !$0.isEmpty }.joined(separator: "/")
        return components.url
    }
}

private struct CompletionRequest: Encodable {
    let model: String
    let messages: [APIMessage]
}

private struct APIMessage: Codable {
    let role: String
    let content: String
}

private struct CompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: APIMessage
    }
}

private struct APIErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}

enum LLMClientError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case codexNotFound(String)
    case codexLaunchFailed(String)
    case codexFailed(status: Int32, message: String?)
    case requestFailed(status: Int, message: String?)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The LLM base URL is invalid."
        case .invalidResponse:
            return "The LLM returned an invalid response."
        case let .codexNotFound(path):
            return path.isEmpty
                ? "Configure the Codex executable path in Settings."
                : "Codex is not executable at \(path)."
        case let .codexLaunchFailed(message):
            return "Could not launch Codex: \(message)"
        case let .codexFailed(status, message):
            return message?.isEmpty == false
                ? message
                : "Codex exited with status \(status). Run ‘codex login’ in Terminal and try again."
        case let .requestFailed(status, message):
            return message ?? "The LLM request failed with status \(status)."
        case .emptyResponse:
            return "The LLM returned an empty response."
        }
    }
}
