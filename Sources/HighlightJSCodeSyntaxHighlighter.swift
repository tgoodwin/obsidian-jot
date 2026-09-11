import AppKit
import Highlighter
import MarkdownUI
import SwiftUI

struct HighlightJSCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private let highlighter: Highlighter?

    init(themeName: String) {
        let highlighter = Highlighter()
        highlighter?.setTheme(themeName, withFont: "Menlo-Regular", ofSize: 12)
        self.highlighter = highlighter
    }

    func highlightCode(_ code: String, language: String?) -> Text {
        guard let highlighted = highlightedCode(code, language: language) else {
            return Text(code)
        }
        return Text(AttributedString(highlighted))
    }

    func highlightedCode(_ code: String, language: String?) -> NSAttributedString? {
        guard let highlighted = highlighter?.highlight(code, as: language) else {
            return nil
        }

        let transparent = NSMutableAttributedString(attributedString: highlighted)
        transparent.removeAttribute(
            .backgroundColor,
            range: NSRange(location: 0, length: transparent.length)
        )
        return transparent
    }
}
