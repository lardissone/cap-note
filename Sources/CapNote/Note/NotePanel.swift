import AppKit

final class NotePanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        titlebarAppearsTransparent = false
        titleVisibility = .hidden
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 300, height: 200)
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
