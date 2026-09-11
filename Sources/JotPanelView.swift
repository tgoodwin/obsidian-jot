import SwiftUI
import AppKit
import MarkdownUI

struct JotPanelView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var session: PanelSession
    @State private var measuredInputHeight: CGFloat = 34

    let onDismiss: () -> Void
    let onDiscard: () -> Void
    let onPreferredHeightChange: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if session.mode == .chat, hasChatActivity {
                chatTranscript
                Divider().opacity(0.5)
            }

            JotTextEditor(
                text: $session.input,
                placeholder: inputPlaceholder,
                onSubmit: submit,
                onCancel: onDiscard,
                onToggleMode: session.toggleMode,
                onContentHeightChange: updateInputHeight
            )
            .frame(
                minHeight: session.mode == .chat ? chatInputHeight : 100,
                maxHeight: session.mode == .chat ? chatInputHeight : .infinity
            )
            .padding(.horizontal, 9)

            if session.mode == .chat, !hasChatActivity {
                Spacer(minLength: 0)
            }

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
            minHeight: 150,
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
        .onChange(of: hasChatActivity) { _, _ in
            onPreferredHeightChange(preferredHeight)
        }
        .onChange(of: measuredInputHeight) { _, _ in
            if session.mode == .chat, !hasChatActivity {
                onPreferredHeightChange(preferredHeight)
            }
        }
    }

    private var chatTranscript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
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
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("chat-bottom")
                }
                .padding(12)
            }
            .defaultScrollAnchor(.bottom)
            .onAppear { scrollToBottom(proxy) }
            .onChange(of: session.messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: session.isSending) { _, _ in scrollToBottom(proxy) }
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
        guard session.mode == .chat else { return 180 }
        return hasChatActivity ? 500 : 150 + max(0, chatInputHeight - 34)
    }

    private var hasChatActivity: Bool {
        !session.messages.isEmpty
    }

    private var chatInputHeight: CGFloat {
        min(max(measuredInputHeight, 34), 140)
    }

    private var inputPlaceholder: String {
        if session.mode == .chat {
            return "Quick chat"
        }
        guard let url = appState.dailyNoteURL else { return "Obsidian Jot" }
        return "Append to \(url.lastPathComponent)"
    }

    private var footerText: String {
        session.mode == .chat
            ? "⏎ to send · ⇧⏎ for newline · tab to jot · esc to dismiss"
            : "⏎ to save · ⇧⏎ for newline · tab to chat · esc to dismiss"
    }

    private func updateInputHeight(_ height: CGFloat) {
        let clamped = min(max(height, 34), 140)
        if abs(measuredInputHeight - clamped) > 0.5 {
            measuredInputHeight = clamped
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            proxy.scrollTo("chat-bottom", anchor: .bottom)
        }
    }

    private func submit() {
        session.submit(appState: appState, onJotSaved: onDismiss)
    }
}

private struct ChatMessageView: View {
    private static let lightHighlighter = HighlightJSCodeSyntaxHighlighter(themeName: "github")
    private static let darkHighlighter = HighlightJSCodeSyntaxHighlighter(themeName: "github-dark")

    @Environment(\.colorScheme) private var colorScheme

    let message: ChatMessage
    let wasSaved: Bool
    let onSave: () -> Void

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: .leading, spacing: 7) {
                Markdown(message.content)
                    .markdownTheme(.jot)
                    .markdownCodeSyntaxHighlighter(
                        colorScheme == .dark ? Self.darkHighlighter : Self.lightHighlighter
                    )
                    .font(.system(size: 13))
                    .textSelection(.enabled)

                if message.role == .assistant {
                    HStack(spacing: 12) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .help("Copy response")
                        .accessibilityLabel("Copy response")

                        Button(action: onSave) {
                            Image(systemName: wasSaved ? "checkmark" : "square.and.arrow.down")
                        }
                        .help(wasSaved ? "Saved to daily note" : "Save to daily note")
                        .accessibilityLabel(wasSaved ? "Saved to daily note" : "Save to daily note")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
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

private extension Theme {
    static let jot = Theme.basic
        .text {
            ForegroundColor(.primary)
            BackgroundColor(nil)
            FontSize(13)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            BackgroundColor(Color.primary.opacity(0.08))
        }
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.15))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.9))
                        BackgroundColor(nil)
                    }
                    .padding(12)
            }
            .background(Color.primary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .markdownMargin(top: 0, bottom: 12)
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
        onDismiss: {},
        onDiscard: {},
        onPreferredHeightChange: { _ in }
    )
    .environmentObject(AppState())
    .padding(40)
}
