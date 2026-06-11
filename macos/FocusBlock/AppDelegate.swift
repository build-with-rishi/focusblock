import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    var calendarManager: CalendarManager!
    var overlayController: OverlayWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayController = OverlayWindowController()
        calendarManager = CalendarManager(onTrigger: { [weak self] event, minutesBefore in
            self?.overlayController.showOverlay(for: event, minutesBefore: minutesBefore)
        })
        statusBarController = StatusBarController(
            calendarManager: calendarManager,
            overlayController: overlayController
        )
        calendarManager.requestAccessAndStart()
    }
}
