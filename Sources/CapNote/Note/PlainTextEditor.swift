import AppKit
import SwiftUI

/// Wraps an `NSTextView` with zero text-container insets and zero
/// line-fragment padding, so that an overlaid placeholder can sit at exactly
/// the same coordinates as the first character. Also intercepts the
/// keyboard shortcuts the panel cares about (Cmd+Enter, Esc, Cmd+,).
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    let focusTrigger: Int
    let onSubmit: () -> Void
    let onEscape: () -> Void
    let onToggleSettings: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = ShortcutTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.font = font
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFontPanel = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.onSubmit = { [weak textView] in
            guard textView != nil else { return }
            context.coordinator.parent.onSubmit()
        }
        textView.onEscape = {
            context.coordinator.parent.onEscape()
        }
        textView.onToggleSettings = {
            context.coordinator.parent.onToggleSettings()
        }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ShortcutTextView else { return }

        if textView.string != text {
            textView.string = text
        }
        if textView.font != font {
            textView.font = font
        }

        // Keep the closures fresh — `parent` reference inside the coordinator
        // already does that for the callbacks defined above.
        context.coordinator.parent = self

        if focusTrigger != context.coordinator.lastFocusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor
        var lastFocusTrigger: Int

        init(_ parent: PlainTextEditor) {
            self.parent = parent
            self.lastFocusTrigger = parent.focusTrigger
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// `NSTextView` subclass that surfaces the keyboard shortcuts the panel
/// cares about as plain closures. Anything else falls through to the
/// default text-handling behavior (multi-line input, cursor movement, …).
final class ShortcutTextView: NSTextView {
    var onSubmit: () -> Void = {}
    var onEscape: () -> Void = {}
    var onToggleSettings: () -> Void = {}

    private static let returnKeyCode: UInt16 = 36
    private static let escapeKeyCode: UInt16 = 53
    private static let commaKeyCode: UInt16 = 43

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommand = modifiers.contains(.command)

        switch event.keyCode {
        case Self.returnKeyCode where isCommand:
            onSubmit()
            return
        case Self.escapeKeyCode:
            onEscape()
            return
        case Self.commaKeyCode where isCommand:
            onToggleSettings()
            return
        default:
            super.keyDown(with: event)
        }
    }
}
