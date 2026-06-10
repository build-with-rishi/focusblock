import AppKit
import EventKit

class OverlayWindowController {
    private var overlayWindows: [OverlayWindow] = []
    private var autoDismissTimer: Timer?

    func showOverlay(for event: EKEvent, minutesBefore: Int) {
        dismissAll() // clean up any existing ones

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)

            let contentView = OverlayContentView(frame: screen.frame)
            contentView.configure(event: event, minutesBefore: minutesBefore)
            window.contentView = contentView

            window.onDismiss = { [weak self] in
                self?.dismissAll()
            }

            overlayWindows.append(window)
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)

        // Auto-dismiss after 8 seconds
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            self?.dismissAll()
        }
    }

    func dismissAll() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    func testOverlay() {
        let mockEvent = EKEvent(eventStore: EKEventStore())
        mockEvent.title = "Test Event"
        mockEvent.startDate = Date().addingTimeInterval(10 * 60)
        mockEvent.endDate = Date().addingTimeInterval(55 * 60)
        showOverlay(for: mockEvent, minutesBefore: 10)
    }
}
