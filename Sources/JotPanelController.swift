import AppKit
import SwiftUI

@MainActor
final class JotPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private let appState: AppState
    private let session = PanelSession()

    init(appState: AppState) {
        self.appState = appState
    }

    func toggle() {
        if let panel, panel.isVisible {
            close()
        } else {
            present()
        }
    }

    func present() {
        if panel == nil {
            panel = makePanel()
        }
        guard let panel else { return }

        centerOnActiveScreen(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        session.reset()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Auto-dismiss when focus is lost — Day-One-style.
        close()
    }

    private func makePanel() -> NSPanel {
        let contentView = JotPanelView(
            session: session,
            onClose: { [weak self] in self?.close() },
            onPreferredHeightChange: { [weak self] height in
                self?.resizePanel(to: height)
            }
        )
        .environmentObject(appState)

        let hosting = NSHostingController(rootView: contentView)
        let size = hosting.view.fittingSize == .zero
            ? NSSize(width: 520, height: 180)
            : hosting.view.fittingSize

        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.contentViewController = hosting
        panel.delegate = self
        return panel
    }

    private func resizePanel(to height: CGFloat) {
        guard let panel, abs(panel.contentLayoutRect.height - height) > 1 else { return }
        let top = panel.frame.maxY
        panel.setContentSize(NSSize(width: 520, height: height))
        panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - panel.frame.height))
    }

    private func centerOnActiveScreen(_ panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else {
            panel.center()
            return
        }
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY + size.height / 2 + 60
        )
        panel.setFrameOrigin(origin)
    }
}

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
