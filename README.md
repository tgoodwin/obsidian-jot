# Obsidian Jot

Menu-bar app for macOS. Press a global hotkey (default ⌃⇧J), type something, hit Enter — it gets appended to today's Obsidian daily note. Press Tab to turn the same panel into a lightweight LLM conversation.

## Build

```bash
brew install xcodegen
xcodegen
open ObsidianJot.xcodeproj
```

Then ⌘R in Xcode. On first launch the Settings window opens — pick your vault folder.

## Quick Chat

Quick Chat uses your local Codex installation and saved ChatGPT login by default. It keeps one `codex app-server` process alive, so later questions avoid CLI startup cost. Run `codex login` in Terminal once if needed. An OpenAI-compatible HTTP backend is also available in Settings; its API key is stored in macOS Keychain.

Open the jot panel and press Tab. The panel expands into chat mode; press Tab again to switch back. Assistant responses can be copied or appended to today's note. Conversation threads are ephemeral and cleared when the panel closes.

## Dev loop

Three speeds:

1. **SwiftUI Previews** — fastest. Open `JotPanelView.swift` or `SettingsView.swift` in Xcode and use the canvas (⌥⌘↩). The `#Preview` blocks render the views in isolation; no app launch, no menu bar, no hotkey. Use this for layout/visual work.
2. **`./dev.sh`** — builds with `xcodebuild`, kills any running `ObsidianJot`, relaunches the fresh build. Use this for end-to-end testing of the hotkey and panel chrome — much faster than ⌘Q + ⌘R in Xcode.
3. **Xcode ⌘R** — full debugger attached. Use when you actually need breakpoints. Note that for menu-bar apps you'll have to manually quit the previous instance before re-running.

The hotkey, `NSPanel` activation behavior, and `MenuBarExtra` only exist in a real launched app, so previews can't cover those.

## Layout

- `Sources/ObsidianJotApp.swift` — `@main`, `MenuBarExtra`, `Settings` scene, `AppDelegate` wires the global hotkey.
- `Sources/JotPanelController.swift` — manages the floating `NSPanel` (Day-One-style).
- `Sources/JotPanelView.swift` — SwiftUI content for jot and chat modes.
- `Sources/PanelSession.swift` — panel mode, ephemeral conversation state, and submission behavior.
- `Sources/CodexAppServerClient.swift` — persistent Codex app-server connection and ephemeral chat threads.
- `Sources/LLMClient.swift` — shared client contract, Codex exec fallback, and OpenAI-compatible client.
- `Sources/KeychainStore.swift` — API-key storage in macOS Keychain.
- `Sources/JotTextEditor.swift` — `NSTextView` wrapper that maps Enter→submit, Shift+Enter→newline, Esc→dismiss.
- `Sources/SettingsView.swift` — vault picker + `KeyboardShortcuts.Recorder`.
- `Sources/AppState.swift` — `@AppStorage`-backed settings, computes today's daily-note URL.
- `Sources/DailyNoteWriter.swift` — appends text to the file (creating it if needed).
- `Sources/ObsidianConfig.swift` — reads `<vault>/.obsidian/daily-notes.json` so the subdirectory and filename format are auto-detected from the user's Obsidian setup.
- `Sources/KeyboardShortcutsNames.swift` — shortcut name registration. Default: ⌃⇧J.

## Notes

- Sandbox is off (`ENABLE_HARDENED_RUNTIME: NO`) for unsigned local dev. If you ever notarize, you'll want to switch to security-scoped bookmarks for the vault path.
- The default daily-note filename format is `yyyy-MM-dd.md`, matching the Obsidian Daily Notes plugin default. Configurable in Settings.
- `LSUIElement = true` keeps the dock icon hidden — menu bar only.
