import Foundation

/// Renders an Obsidian daily-note template into the text that should
/// initialize a fresh daily-note file. Handles the three placeholders
/// the Daily Notes plugin documents:
///   - {{date}}              uses the daily-note filename format
///   - {{date:FORMAT}}       FORMAT is moment.js, e.g. {{date:dddd}}
///   - {{time}}              defaults to HH:mm
///   - {{time:FORMAT}}
///   - {{title}}             the rendered filename, sans extension
struct DailyNoteTemplate {
    let vaultPath: String
    /// Path stored in `daily-notes.json`, e.g. `templates/daily`. Optional `.md`.
    let templatePath: String

    func render(forDate date: Date, defaultDateFormat: String) -> String? {
        let url = resolveURL()
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let title = (DailyNoteTemplate.formatted(date, momentFormat: defaultDateFormat)
                     ?? DailyNoteTemplate.formatted(date, foundationFormat: defaultDateFormat))
                    ?? ""

        var rendered = raw
        rendered = substitute(rendered, token: "date", date: date, defaultFormat: defaultDateFormat)
        rendered = substitute(rendered, token: "time", date: date, defaultFormat: "HH:mm")
        rendered = rendered.replacingOccurrences(of: "{{title}}", with: title)
        return rendered
    }

    private func resolveURL() -> URL {
        var path = templatePath
        if !path.hasSuffix(".md") { path += ".md" }
        return URL(fileURLWithPath: vaultPath).appendingPathComponent(path)
    }

    /// Replace `{{token}}` and `{{token:FORMAT}}` with formatted dates.
    /// FORMAT inside the template is moment.js, since it comes from
    /// Obsidian's UI conventions.
    private func substitute(_ input: String, token: String, date: Date, defaultFormat: String) -> String {
        let pattern = "\\{\\{\(token)(?::([^}]+))?\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }

        let ns = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: ns.length))

        var result = input
        for match in matches.reversed() {
            let fullRange = match.range
            let format: String
            if match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound {
                format = ns.substring(with: match.range(at: 1))
            } else {
                format = defaultFormat
            }
            let replacement = DailyNoteTemplate.formatted(date, momentFormat: format) ?? ""
            let swiftRange = Range(fullRange, in: result)!
            result.replaceSubrange(swiftRange, with: replacement)
        }
        return result
    }

    static func formatted(_ date: Date, momentFormat: String) -> String? {
        formatted(date, foundationFormat: ObsidianConfig.convertMomentFormat(momentFormat))
    }

    static func formatted(_ date: Date, foundationFormat: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = foundationFormat
        return formatter.string(from: date)
    }
}
