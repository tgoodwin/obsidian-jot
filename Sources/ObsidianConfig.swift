import Foundation

struct ObsidianDailyNotesConfig: Decodable {
    let folder: String?
    let format: String?
}

enum ObsidianConfig {
    /// Reads `<vault>/.obsidian/daily-notes.json` if present.
    static func loadDailyNotes(vaultPath: String) -> ObsidianDailyNotesConfig? {
        let url = URL(fileURLWithPath: vaultPath)
            .appendingPathComponent(".obsidian/daily-notes.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ObsidianDailyNotesConfig.self, from: data)
    }

    /// Convert a moment.js date format (used by Obsidian) to a Foundation
    /// `DateFormatter` format. Handles only the tokens commonly used for
    /// daily-note filenames; falls back to passing the input through.
    static func convertMomentFormat(_ moment: String) -> String {
        // Order matters — replace longer tokens first.
        let mappings: [(String, String)] = [
            ("YYYY", "yyyy"),
            ("YY", "yy"),
            ("DD", "dd"),
            ("Do", "d"),
            ("dddd", "EEEE"),
            ("ddd", "EEE"),
            ("D", "d"),
            // MM, M, HH, mm, ss are already the same in DateFormatter.
        ]
        var result = moment
        for (from, to) in mappings {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }
}
