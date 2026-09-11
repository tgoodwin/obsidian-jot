import AppKit
import Foundation

@MainActor
final class PanelSession: ObservableObject {
    enum Mode {
        case jot
        case chat
    }

    @Published var mode: Mode = .jot
    @Published var input = ""
    @Published var messages: [ChatMessage] = []
    @Published var errorMessage: String?
    @Published var isSending = false
    @Published var savedMessageID: UUID?

    private let codexClient = CodexAppServerClient()
    private let apiClient: any LLMClient
    private var requestTask: Task<Void, Never>?

    init(apiClient: any LLMClient = OpenAICompatibleClient()) {
        self.apiClient = apiClient
    }

    func submit(appState: AppState, onJotSaved: () -> Void) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if mode == .jot, trimmed == "/chat" || trimmed.hasPrefix("/chat ") {
            mode = .chat
            errorMessage = nil
            input = String(trimmed.dropFirst("/chat".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !input.isEmpty {
                send(appState: appState)
            }
            return
        }

        if mode == .chat, trimmed == "/jot" {
            mode = .jot
            input = ""
            errorMessage = nil
            return
        }

        switch mode {
        case .jot:
            if appendToDailyNote(trimmed, appState: appState) {
                input = ""
                onJotSaved()
            }
        case .chat:
            send(appState: appState)
        }
    }

    func saveToDailyNote(_ message: ChatMessage, appState: AppState) {
        if appendToDailyNote(message.content, appState: appState) {
            savedMessageID = message.id
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                if self?.savedMessageID == message.id {
                    self?.savedMessageID = nil
                }
            }
        }
    }

    func reset() {
        requestTask?.cancel()
        requestTask = nil
        Task { await codexClient.resetThread() }
        mode = .jot
        input = ""
        messages = []
        errorMessage = nil
        isSending = false
        savedMessageID = nil
    }

    private func send(appState: AppState) {
        guard !isSending else { return }
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        let usesCodex = appState.llmProvider == "codexCLI"
        if !usesCodex, appState.llmModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Configure an LLM model in Settings."
            return
        }

        messages.append(ChatMessage(role: .user, content: prompt))
        input = ""
        errorMessage = nil
        isSending = true

        let history = messages
        let configuration = LLMConfiguration(
            baseURL: appState.llmBaseURL,
            model: usesCodex ? appState.codexModel : appState.llmModel,
            apiKey: KeychainStore.readAPIKey(),
            codexExecutablePath: appState.codexExecutablePath
        )
        requestTask = Task { [weak self, codexClient, apiClient] in
            do {
                let response: String
                if usesCodex {
                    response = try await codexClient.complete(messages: history, configuration: configuration)
                } else {
                    response = try await apiClient.complete(messages: history, configuration: configuration)
                }
                try Task.checkCancellation()
                self?.messages.append(ChatMessage(role: .assistant, content: response))
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = error.localizedDescription
            }
            self?.isSending = false
            self?.requestTask = nil
        }
    }

    @discardableResult
    private func appendToDailyNote(_ text: String, appState: AppState) -> Bool {
        guard let url = appState.dailyNoteURL else {
            errorMessage = "Vault not configured. Open Settings."
            return false
        }
        let template = appState.dailyNoteTemplate.isEmpty ? nil : DailyNoteTemplate(
            vaultPath: appState.vaultPath,
            templatePath: appState.dailyNoteTemplate
        )
        let writer = DailyNoteWriter(
            fileURL: url,
            template: template,
            dateFormat: appState.dailyNoteFormat,
            sectionHeading: appState.jotsHeading,
            sectionLevel: appState.jotsHeadingLevel
        )
        do {
            try writer.append(text)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}
