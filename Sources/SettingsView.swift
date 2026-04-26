import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var loginItem = LoginItem()

    var body: some View {
        Form {
            Section("Vault") {
                HStack {
                    TextField(
                        "Path",
                        text: Binding(
                            get: { appState.vaultPath },
                            set: { appState.vaultPath = $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    Button("Choose…", action: pickVault)
                }
                TextField("Daily-note subdirectory (optional)", text: $appState.dailyNoteSubdirectory)
                TextField("Filename format", text: $appState.dailyNoteFormat)
                TextField("Template path (optional)", text: $appState.dailyNoteTemplate)
                HStack {
                    Spacer()
                    Button("Detect from Obsidian") {
                        applyObsidianDefaults(for: appState.vaultPath)
                    }
                    .disabled(appState.vaultPath.isEmpty)
                }
                if let url = appState.dailyNoteURL {
                    Text("Today's note: \(url.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }

            Section("Section") {
                TextField("Heading text (empty = append at end of file)", text: $appState.jotsHeading)
                Stepper(value: $appState.jotsHeadingLevel, in: 1...6) {
                    Text("Heading level: H\(appState.jotsHeadingLevel)")
                }
                if !appState.jotsHeading.isEmpty {
                    Text("Jots will land under \(String(repeating: "#", count: appState.jotsHeadingLevel)) \(appState.jotsHeading)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Toggle jot panel:", name: .toggleJotPanel)
            }

            Section("Startup") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    )
                )
                if loginItem.requiresApproval {
                    Text("Login item needs approval in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .onAppear { loginItem.refresh() }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 480, height: 460)
    }

    private func pickVault() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Vault"
        panel.message = "Choose your Obsidian vault folder."
        if panel.runModal() == .OK, let url = panel.url {
            appState.vaultPath = url.path
            applyObsidianDefaults(for: url.path)
        }
    }

    private func applyObsidianDefaults(for vaultPath: String) {
        guard let config = ObsidianConfig.loadDailyNotes(vaultPath: vaultPath) else { return }
        if let folder = config.folder, !folder.isEmpty {
            appState.dailyNoteSubdirectory = folder
        }
        if let format = config.format, !format.isEmpty {
            appState.dailyNoteFormat = ObsidianConfig.convertMomentFormat(format)
        }
        if let template = config.template, !template.isEmpty {
            appState.dailyNoteTemplate = template
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
