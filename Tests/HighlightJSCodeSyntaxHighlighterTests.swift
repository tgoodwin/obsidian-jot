import AppKit
import XCTest
@testable import ObsidianJot

final class HighlightJSCodeSyntaxHighlighterTests: XCTestCase {
    func testHighlightsPythonWithMultipleTokenColors() throws {
        let highlighter = HighlightJSCodeSyntaxHighlighter(themeName: "github-dark")

        let result = try XCTUnwrap(highlighter.highlightedCode(
            "def greet(name):\n    return f\"Hello, {name}!\"",
            language: "python"
        ))
        var colors = Set<String>()
        result.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: result.length)
        ) { value, _, _ in
            if let color = value as? NSColor {
                colors.insert(color.description)
            }
        }

        XCTAssertGreaterThan(colors.count, 1)
    }

    func testRemovesOpaqueThemeBackgroundFromHighlightedCode() throws {
        let highlighter = HighlightJSCodeSyntaxHighlighter(themeName: "github-dark")

        let result = try XCTUnwrap(highlighter.highlightedCode(
            "let answer = 42",
            language: "swift"
        ))
        var foundBackground = false
        result.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: result.length)
        ) { value, _, stop in
            if value != nil {
                foundBackground = true
                stop.pointee = true
            }
        }

        XCTAssertFalse(foundBackground)
    }
}
