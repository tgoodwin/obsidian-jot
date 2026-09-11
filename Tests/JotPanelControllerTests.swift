import XCTest
@testable import ObsidianJot

@MainActor
final class JotPanelControllerTests: XCTestCase {
    func testDismissPreservesCurrentSession() {
        let session = PanelSession()
        session.mode = .chat
        session.input = "unfinished question"
        session.messages = [ChatMessage(role: .assistant, content: "Previous answer")]
        let controller = JotPanelController(appState: AppState(), session: session)

        controller.dismiss()

        XCTAssertEqual(session.mode, .chat)
        XCTAssertEqual(session.input, "unfinished question")
        XCTAssertEqual(session.messages.count, 1)
    }

    func testEscapeStyleDismissClearsCurrentSession() {
        let session = PanelSession()
        session.mode = .chat
        session.input = "unfinished question"
        session.messages = [ChatMessage(role: .assistant, content: "Previous answer")]
        let controller = JotPanelController(appState: AppState(), session: session)

        controller.discardAndDismiss()

        XCTAssertEqual(session.mode, .jot)
        XCTAssertTrue(session.input.isEmpty)
        XCTAssertTrue(session.messages.isEmpty)
    }
}
