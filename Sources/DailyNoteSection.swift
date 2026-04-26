import Foundation

/// Inserts a jot into a specific markdown section of a daily note. If the
/// section heading exists, the text is appended at the end of that section
/// (just before the next same-or-higher-level heading). If it doesn't exist,
/// the heading is appended at the end of the file followed by the text.
enum DailyNoteSection {
    static func insert(
        into content: String,
        heading: String,
        level: Int,
        text: String
    ) -> String {
        let lines = content.components(separatedBy: "\n")
        let level = max(1, min(level, 6))
        let headingLine = String(repeating: "#", count: level) + " " + heading

        if let headingIdx = lines.firstIndex(where: { isHeadingLine($0, expected: headingLine) }) {
            let sectionEnd = endOfSection(in: lines, after: headingIdx, currentLevel: level)
            var insertIdx = sectionEnd
            while insertIdx > headingIdx + 1,
                  lines[insertIdx - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                insertIdx -= 1
            }

            var rebuilt = Array(lines[0..<insertIdx])
            rebuilt.append("")
            rebuilt.append(text)
            rebuilt.append("")
            rebuilt.append(contentsOf: lines[insertIdx..<lines.count])
            return rebuilt.joined(separator: "\n")
        }

        // Section missing — append heading and text at EOF.
        var rebuilt = lines
        while let last = rebuilt.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            rebuilt.removeLast()
        }
        rebuilt.append("")
        rebuilt.append(headingLine)
        rebuilt.append("")
        rebuilt.append(text)
        rebuilt.append("")
        return rebuilt.joined(separator: "\n")
    }

    private static func isHeadingLine(_ line: String, expected: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == expected
    }

    /// Returns the index in `lines` of the first heading at level <=
    /// `currentLevel` after `headingIdx`, or `lines.count` if none.
    private static func endOfSection(in lines: [String], after headingIdx: Int, currentLevel: Int) -> Int {
        var i = headingIdx + 1
        while i < lines.count {
            if let level = headingLevel(of: lines[i]), level <= currentLevel {
                return i
            }
            i += 1
        }
        return lines.count
    }

    private static func headingLevel(of line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        var count = 0
        for ch in trimmed {
            if ch == "#" { count += 1 } else { break }
        }
        guard count > 0, count <= 6 else { return nil }
        // A valid ATX heading requires a space after the `#`s.
        let afterHashes = trimmed.index(trimmed.startIndex, offsetBy: count)
        guard afterHashes < trimmed.endIndex, trimmed[afterHashes] == " " else { return nil }
        return count
    }
}
