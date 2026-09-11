import SwiftUI
import AppKit
import MarkdownUI

struct JotPanelView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var session: PanelSession

    let onClose: () -> Void
    let onPreferredHeightChange: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            if session.mode == .chat {
                chatTranscript
                Divider().opacity(0.5)
            }

            JotTextEditor(
                text: $session.input,
                onSubmit: submit,
                onCancel: onClose,
                onToggleMode: session.toggleMode
            )
            .frame(minHeight: session.mode == .chat ? 72 : 100, maxHeight: session.mode == .chat ? 100 : 220)
            .padding(.horizontal, 10)

            if let errorMessage = session.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
            }

            footer
        }
        .frame(
            minWidth: 420,
            idealWidth: 520,
            maxWidth: .infinity,
            minHeight: session.mode == .chat ? 320 : 150,
            idealHeight: preferredHeight,
            maxHeight: .infinity
        )
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear { onPreferredHeightChange(preferredHeight) }
        .onChange(of: session.mode) { _, _ in
            onPreferredHeightChange(preferredHeight)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: session.mode == .chat ? "bubble.left" : "square.and.pencil")
                .foregroundStyle(.secondary)
            Text(headerText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if session.mode == .chat {
                Text(chatModelLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var chatTranscript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if session.messages.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 22))
                            Text("Ask a quick question")
                                .font(.system(size: 13, weight: .medium))
                            Text("This conversation is cleared when the panel closes.")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }

                    ForEach(session.messages) { message in
                        ChatMessageView(
                            message: message,
                            wasSaved: session.savedMessageID == message.id,
                            onSave: { session.saveToDailyNote(message, appState: appState) }
                        )
                        .id(message.id)
                    }

                    if session.isSending {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Thinking…")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .id("thinking")
                    }
                }
                .padding(12)
            }
            .onChange(of: session.messages.count) { _, _ in
                if let lastID = session.messages.last?.id {
                    withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
            .onChange(of: session.isSending) { _, sending in
                if sending {
                    withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(footerText)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var preferredHeight: CGFloat {
        session.mode == .chat ? 500 : 180
    }

    private var chatModelLabel: String {
        if appState.llmProvider == "codexCLI" {
            return appState.codexModel.isEmpty ? "Codex" : appState.codexModel
        }
        return appState.llmModel
    }

    private var headerText: String {
        if session.mode == .chat {
            return "Quick Chat"
        }
        guard let url = appState.dailyNoteURL else { return "Obsidian Jot" }
        return "Append to \(url.lastPathComponent)"
    }

    private var footerText: String {
        session.mode == .chat
            ? "⏎ to send · ⇧⏎ for newline · tab to jot · esc to dismiss"
            : "⏎ to save · ⇧⏎ for newline · tab to chat · esc to dismiss"
    }

    private func submit() {
        session.submit(appState: appState, onJotSaved: onClose)
    }
}

private struct ChatMessageView: View {
    let message: ChatMessage
    let wasSaved: Bool
    let onSave: () -> Void

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: .leading, spacing: 7) {
                Markdown(message.content)
                    .markdownTheme(.gitHub)
                    .font(.system(size: 13))
                    .textSelection(.enabled)

                if message.role == .assistant {
                    HStack(spacing: 10) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        Button(action: onSave) {
                            Label(wasSaved ? "Saved" : "Save to note", systemImage: wasSaved ? "checkmark" : "square.and.arrow.down")
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                message.role == .user
                    ? Color.primary.opacity(0.12)
                    : Color.primary.opacity(0.07)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            if message.role == .assistant { Spacer(minLength: 32) }
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

#Preview {
    JotPanelView(
        session: PanelSession(),
        onClose: {},
        onPreferredHeightChange: { _ in }
    )
    .environmentObject(AppState())
    .padding(40)
}
