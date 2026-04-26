import SwiftUI
import KeyboardShortcuts

@main
struct ObsidianJotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Jot", systemImage: "square.and.pencil") {
            MenuBarContent()
                .environmentObject(appDelegate.appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("New jot…") {
            AppDelegate.shared?.panelController.present()
        }
        .keyboardShortcut("n")

        Divider()

        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")

        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    let appState = AppState()
    lazy var panelController = JotPanelController(appState: appState)

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        KeyboardShortcuts.onKeyDown(for: .toggleJotPanel) { [weak self] in
            self?.panelController.toggle()
        }

        if !appState.isConfigured {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}
