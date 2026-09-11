import XCTest
@testable import ObsidianJot

final class ChatResponseAccumulatorTests: XCTestCase {
    func testPreservesMarkdownAcrossStreamChunks() {
        let expected = """
        # Heading

        **Bold**, *italic*, `inline code`, and [a link](https://example.com).

        - first
        - second

        > A blockquote

        ```swift
        let answer = 42
        ```

        | Name | Value |
        | --- | ---: |
        | answer | 42 |
        """
        let chunks = [
            "# Head",
            "ing\n\n**Bold**, *italic*, `inline code`, and ",
            "[a link](https://example.com).\n\n- first\n- second\n\n",
            "> A blockquote\n\n```swift\nlet answer = 42\n```\n\n",
            "| Name | Value |\n| --- | ---: |\n| answer | 42 |"
        ]

        var response = ChatResponseAccumulator()
        chunks.forEach { response.append($0) }

        XCTAssertEqual(response.text, expected)
    }

    func testUsesCompletedMessageWhenNoDeltasArrive() {
        var response = ChatResponseAccumulator()

        response.useCompletedTextIfEmpty("**complete**")

        XCTAssertEqual(response.text, "**complete**")
    }

    func testCompletedMessageDoesNotDuplicateStreamedMarkdown() {
        var response = ChatResponseAccumulator()
        response.append("- streamed item")

        response.useCompletedTextIfEmpty("- streamed item")

        XCTAssertEqual(response.text, "- streamed item")
    }

    func testResetClearsPreviousResponse() {
        var response = ChatResponseAccumulator()
        response.append("# Previous response")

        response.reset()

        XCTAssertTrue(response.text.isEmpty)
    }
}
