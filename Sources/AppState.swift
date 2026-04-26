import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @AppStorage("vaultPath") var vaultPath: String = ""
    @AppStorage("dailyNoteFormat") var dailyNoteFormat: String = "yyyy-MM-dd"
    @AppStorage("dailyNoteSubdirectory") var dailyNoteSubdirectory: String = ""
    @AppStorage("dailyNoteTemplate") var dailyNoteTemplate: String = ""

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
