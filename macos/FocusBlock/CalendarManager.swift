import EventKit
import Foundation
import AppKit

struct TriggerKey: Hashable {
    let eventID: String
    let window: Int // 30, 10, or 5
}

class CalendarManager {
    private let store = EKEventStore()
    private var timer: Timer?
    private var shownTriggers: Set<TriggerKey> = []
    private let onTrigger: (EKEvent, Int) -> Void

    // Which time windows are enabled (30, 10, 5 minutes before)
    var enabledWindows: Set<Int> = [30, 10, 5]

    init(onTrigger: @escaping (EKEvent, Int) -> Void) {
        self.onTrigger = onTrigger
    }

    func requestAccessAndStart() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        self?.startPolling()
                    } else {
                        self?.showPermissionDeniedAlert()
                    }
                }
            }
        } else {
            requestLegacyAccess()
        }
    }

    // Annotated deprecated so the pre-macOS-14 EventKit API can be called without a warning.
    @available(macOS, deprecated: 14.0)
    private func requestLegacyAccess() {
        store.requestAccess(to: .event) { [weak self] granted, _ in
            DispatchQueue.main.async {
                if granted {
                    self?.startPolling()
                } else {
                    self?.showPermissionDeniedAlert()
                }
            }
        }
    }

    private func startPolling() {
        checkEvents() // immediate first check
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkEvents()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func checkEvents() {
        let now = Date()
        let lookAhead = now.addingTimeInterval(35 * 60)
        let predicate = store.predicateForEvents(withStart: now, end: lookAhead, calendars: nil)
        let events = store.events(matching: predicate)

        for event in events {
            guard let start = event.startDate, let eventID = event.eventIdentifier else { continue }
            let minutesUntil = Int(start.timeIntervalSince(now) / 60)

            for window in enabledWindows {
                if minutesUntil >= (window - 1) && minutesUntil <= (window + 1) {
                    let key = TriggerKey(eventID: eventID, window: window)
                    if !shownTriggers.contains(key) {
                        shownTriggers.insert(key)
                        DispatchQueue.main.async {
                            self.onTrigger(event, window)
                        }
                    }
                }
            }
        }
    }

    func nextEvent() -> EKEvent? {
        let now = Date()
        let lookahead = now.addingTimeInterval(24 * 3600)
        let predicate = store.predicateForEvents(withStart: now, end: lookahead, calendars: nil)
        return store.events(matching: predicate).first
    }

    private func showPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Calendar Access Required"
        alert.informativeText = "FocusBlock needs access to your Calendar to show event reminders. Please grant access in System Settings > Privacy & Security > Calendars."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
        } else {
            NSApp.terminate(nil)
        }
    }
}
