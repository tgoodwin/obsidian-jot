import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @AppStorage("vaultPath") var vaultPath: String = ""
    @AppStorage("dailyNoteFormat") var dailyNoteFormat: String = "yyyy-MM-dd"
    @AppStorage("dailyNoteSubdirectory") var dailyNoteSubdirectory: String = ""
    @AppStorage("dailyNoteTemplate") var dailyNoteTemplate: String = ""
    @AppStorage("jotsHeading") var jotsHeading: String = "Jots"
    @AppStorage("jotsHeadingLevel") var jotsHeadingLevel: Int = 2
    @AppStorage("llmProvider") var llmProvider: String = "codexCLI"
    @AppStorage("llmBaseURL") var llmBaseURL: String = "https://api.openai.com/v1"
    @AppStorage("llmModel") var llmModel: String = "gpt-4.1-mini"
    @AppStorage("codexExecutablePath") var codexExecutablePath: String = "/opt/homebrew/bin/codex"
    @AppStorage("codexModel") var codexModel: String = ""

    var isConfigured: Bool {
        !vaultPath.isEmpty && FileManager.default.fileExists(atPath: vaultPath)
    }

    var dailyNoteURL: URL? {
        guard !vaultPath.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = dailyNoteFormat
        let filename = "\(formatter.string(from: Date())).md"
        var url = URL(fileURLWithPath: vaultPath)
        if !dailyNoteSubdirectory.isEmpty {
            url.appendPathComponent(dailyNoteSubdirectory, isDirectory: true)
        }
        url.appendPathComponent(filename)
        return url
    }
}
