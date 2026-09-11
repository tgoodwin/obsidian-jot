import SwiftUI
import AppKit

struct JotTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onToggleMode: () -> Void
    let onContentHeightChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = SubmittingTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.placeholder = placeholder
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel
        textView.onToggleMode = onToggleMode
        textView.onContentHeightChange = onContentHeightChange

        textView.translatesAutoresizingMaskIntoConstraints = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? SubmittingTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.placeholder = placeholder
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel
        textView.onToggleMode = onToggleMode
        textView.onContentHeightChange = onContentHeightChange

        DispatchQueue.main.async {
            textView.reportContentHeight()
            if textView.window?.firstResponder !== textView {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JotTextEditor
        weak var textView: NSTextView?

        init(_ parent: JotTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? SubmittingTextView else { return }
            parent.text = textView.string
            textView.reportContentHeight()
        }
    }
}

final class SubmittingTextView: NSTextView {
    var placeholder = "" {
        didSet { needsDisplay = true }
    }
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onToggleMode: (() -> Void)?
    var onContentHeightChange: ((CGFloat) -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        (placeholder as NSString).draw(
            at: NSPoint(x: textContainerInset.width, y: textContainerInset.height),
            withAttributes: attributes
        )
    }

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = abs(frame.width - newSize.width) > 0.5
        super.setFrameSize(newSize)
        if widthChanged {
            DispatchQueue.main.async { [weak self] in
                self?.reportContentHeight()
            }
        }
    }

    func reportContentHeight() {
        guard let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let textHeight = layoutManager.usedRect(for: textContainer).height
        let height = ceil(textHeight + textContainerInset.height * 2)
        onContentHeightChange?(height)
    }

    override func keyDown(with event: NSEvent) {
        // Tab toggles between jot and chat modes.
        if event.keyCode == 48 {
            onToggleMode?()
            return
        }
        // Return / Enter without Shift → submit. Shift+Return inserts a newline.
        if event.keyCode == 36 || event.keyCode == 76 {
            if !event.modifierFlags.contains(.shift) {
                onSubmit?()
                return
            }
        }
        // Escape
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }
}
