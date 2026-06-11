import AppKit

class OverlayWindow: NSWindow {
    var onKeyEvent: ((NSEvent) -> Void)?

    init(screen: NSScreen) {
        // The screen: variant is a convenience initializer and can't be called
        // from a subclass; setFrame(screen.frame) below places the window instead.
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        self.backgroundColor = .black
        self.isOpaque = true
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.setFrame(screen.frame, display: true)
        self.isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyEvent?(event)
    }
}
