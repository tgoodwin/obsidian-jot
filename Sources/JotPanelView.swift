import SwiftUI
import AppKit

struct JotPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var text: String = ""
    @State private var errorMessage: String?

    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.secondary)
                Text(headerText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            JotTextEditor(
                text: $text,
                onSubmit: submit,
                onCancel: onClose
            )
            .frame(minHeight: 100, maxHeight: 220)
            .padding(.horizontal, 10)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
            }

            HStack {
                Text("⏎ to save · ⇧⏎ for newline · esc to dismiss")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 520)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var headerText: String {
        guard let url = appState.dailyNoteURL else { return "Obsidian Jot" }
        return "Append to \(url.lastPathComponent)"
    }

    private func submit() {
        guard let url = appState.dailyNoteURL else {
            errorMessage = "Vault not configured. Open Settings."
            return
        }
        do {
            try DailyNoteWriter(fileURL: url).append(text)
            text = ""
            errorMessage = nil
            onClose()
        } catch {
            errorMessage = error.localizedDescription
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
    JotPanelView(onClose: {})
        .environmentObject(AppState())
        .padding(40)
}
