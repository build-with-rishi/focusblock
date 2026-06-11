import AppKit
import EventKit
import ServiceManagement

class StatusBarController {
    private var statusItem: NSStatusItem!
    private let calendarManager: CalendarManager
    private let overlayController: OverlayWindowController

    init(calendarManager: CalendarManager, overlayController: OverlayWindowController) {
        self.calendarManager = calendarManager
        self.overlayController = overlayController
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "FocusBlock")
            button.image?.isTemplate = true
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        // Next event info
        let nextEvent = calendarManager.nextEvent()
        let infoItem = NSMenuItem()
        if let event = nextEvent, let startDate = event.startDate {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeStr = formatter.string(from: startDate)
            infoItem.title = "Next: \(event.title ?? "Event") at \(timeStr)"
        } else {
            infoItem.title = "No upcoming events"
        }
        infoItem.isEnabled = false
        menu.addItem(infoItem)
        menu.addItem(.separator())

        // Test overlay
        let testItem = NSMenuItem(title: "Test Overlay", action: #selector(testOverlay), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)
        menu.addItem(.separator())

        // Time window toggles
        let windowsHeader = NSMenuItem()
        windowsHeader.title = "Alert Windows"
        windowsHeader.isEnabled = false
        menu.addItem(windowsHeader)

        for minutes in [30, 10, 5] {
            let item = NSMenuItem(
                title: "\(minutes) minutes before",
                action: #selector(toggleWindow(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = minutes
            item.state = calendarManager.enabledWindows.contains(minutes) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Alarm sound picker
        let soundItem = NSMenuItem(title: "Alarm Sound", action: nil, keyEquivalent: "")
        let soundMenu = NSMenu()
        for name in AlarmSound.availableNames() {
            let item = NSMenuItem(title: name, action: #selector(selectAlarmSound(_:)), keyEquivalent: "")
            item.target = self
            item.state = name == AlarmSound.selectedName ? .on : .off
            soundMenu.addItem(item)
        }
        soundItem.submenu = soundMenu
        menu.addItem(soundItem)

        menu.addItem(.separator())

        // Launch at login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit FocusBlock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func testOverlay() {
        overlayController.testOverlay()
    }

    @objc private func toggleWindow(_ sender: NSMenuItem) {
        let minutes = sender.tag
        if calendarManager.enabledWindows.contains(minutes) {
            calendarManager.enabledWindows.remove(minutes)
            sender.state = .off
        } else {
            calendarManager.enabledWindows.insert(minutes)
            sender.state = .on
        }
    }

    @objc private func selectAlarmSound(_ sender: NSMenuItem) {
        AlarmSound.selectedName = sender.title
        for item in sender.menu?.items ?? [] {
            item.state = item == sender ? .on : .off
        }
        AlarmSound.preview()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.isEnabled.toggle()
        buildMenu() // rebuild to refresh state
    }
}

// Minimal launch at login helper backed by SMAppService (macOS 13+)
struct LaunchAtLogin {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("LaunchAtLogin toggle failed: \(error.localizedDescription)")
            }
        }
    }
}
