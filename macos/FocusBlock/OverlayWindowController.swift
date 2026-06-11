import AppKit
import EventKit

class OverlayWindowController {
    private var overlayWindows: [OverlayWindow] = []
    private var contentViews: [OverlayContentView] = []
    private var autoDismissTimer: Timer?
    private var challengeWord: String = ""
    private var typedCount: Int = 0
    private var alarmSound: NSSound?

    private static let challengeWords = [
        "FOCUS", "COMMIT", "BEGIN", "ARRIVE", "PRESENT",
        "DELIVER", "ENGAGE", "PREPARE", "SHOWUP", "READY"
    ]

    private static let quotes = [
        "This meeting happens with or without your attention. Choose with.",
        "Stop negotiating with yourself. Wrap up and show up.",
        "You said yes to this. Honor it.",
        "Avoiding it won't cancel it.",
        "Five minutes of prep beats thirty minutes of apologizing.",
        "Close the tabs. The meeting is the work now.",
        "You don't need motivation. You need to stand up.",
        "Every minute you stall, the meeting gets harder.",
        "The dread dies the moment you start moving.",
        "Showing up late is a decision. So is showing up ready.",
        "Discomfort now or regret later. Pick one.",
        "You're not in flow. You're avoiding.",
        "Stop scrolling. Start moving.",
        "Finish the sentence, save the file, go.",
        "The work will wait. The meeting won't.",
        "Your future self is begging you to get up now.",
        "Nothing on your screen matters more than the next hour.",
        "Be the person who walks in prepared.",
        "Procrastination is fear wearing comfortable clothes.",
        "Win the hour by walking in ready."
    ]

    func showOverlay(for event: EKEvent, minutesBefore: Int) {
        dismissAll() // clean up any existing ones

        challengeWord = Self.challengeWords.randomElement()!
        typedCount = 0
        let quote = Self.quotes.randomElement()!

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)

            let contentView = OverlayContentView(frame: screen.frame)
            contentView.configure(
                event: event,
                minutesBefore: minutesBefore,
                quote: quote,
                challengeWord: challengeWord
            )
            window.contentView = contentView

            window.onKeyEvent = { [weak self] keyEvent in
                self?.handleKey(keyEvent)
            }

            overlayWindows.append(window)
            contentViews.append(contentView)
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
        startAlarm()

        // Safety fallback: never leave the screens locked for more than 30 seconds
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.dismissAll()
        }
    }

    private func startAlarm() {
        AlarmSound.stopPreview()
        let alarm = AlarmSound.makeSound()
        alarm?.loops = true
        alarm?.play()
        alarmSound = alarm
    }

    private func stopAlarm() {
        alarmSound?.stop()
        alarmSound = nil
    }

    private func handleKey(_ event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers,
              let typed = characters.uppercased().first,
              typed.isLetter else {
            return // arrows, Esc, function keys: neither advance nor reset
        }

        let word = Array(challengeWord)
        if typedCount < word.count && typed == word[typedCount] {
            typedCount += 1
            if typedCount == word.count {
                dismissAll()
                NSSound(named: "Hero")?.play()
                return
            }
        } else {
            typedCount = 0
            NSSound(named: "Basso")?.play()
        }

        for view in contentViews {
            view.update(typedCount: typedCount)
        }
    }

    func dismissAll() {
        stopAlarm()
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        contentViews.removeAll()
        typedCount = 0
    }

    func testOverlay() {
        let mockEvent = EKEvent(eventStore: EKEventStore())
        mockEvent.title = "Test Event"
        mockEvent.startDate = Date().addingTimeInterval(10 * 60)
        mockEvent.endDate = Date().addingTimeInterval(55 * 60)
        showOverlay(for: mockEvent, minutesBefore: 10)
    }
}
