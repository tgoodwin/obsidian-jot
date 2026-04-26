import Foundation

enum DailyNoteWriterError: Error, LocalizedError {
    case noVaultConfigured
    case directoryMissing(URL)
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noVaultConfigured:
            return "No vault path configured."
        case .directoryMissing(let url):
            return "Daily-note directory does not exist: \(url.path)"
        case .writeFailed(let underlying):
            return "Could not write daily note: \(underlying.localizedDescription)"
        }
    }
}

struct DailyNoteWriter {
    let fileURL: URL
    /// Used to populate the file with template content the first time it
    /// is written, so jots don't bypass the user's Obsidian daily-note template.
    var template: DailyNoteTemplate?
    var dateFormat: String = "yyyy-MM-dd"

    func append(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let directory = fileURL.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw DailyNoteWriterError.directoryMissing(directory)
        }

        let payload = "\n\(trimmed)\n"
        guard let data = payload.data(using: .utf8) else { return }

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                let initial = renderedTemplate() ?? ""
                let combined = initial + payload
                try (combined.data(using: .utf8) ?? Data()).write(to: fileURL, options: .atomic)
            }
        } catch {
            throw DailyNoteWriterError.writeFailed(error)
        }
    }

    private func renderedTemplate() -> String? {
        guard let template else { return nil }
        return template.render(forDate: Date(), defaultDateFormat: dateFormat)
    }
}
