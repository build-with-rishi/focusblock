import AppKit
import EventKit

class OverlayWindowController {
    private var overlayWindows: [OverlayWindow] = []
    private var contentViews: [OverlayContentView] = []
    private var autoDismissTimer: Timer?
    private var challengeWord: String = ""
    private var typedCount: Int = 0

    private static let challengeWords = [
        "FOCUS", "COMMIT", "BEGIN", "ARRIVE", "PRESENT",
        "DELIVER", "ENGAGE", "PREPARE", "SHOWUP", "READY"
    ]

    private static let quotes = [
        "You don't have to be great to start, but you have to start to be great.",
        "Procrastination is the thief of time.",
        "The best way to get something done is to begin.",
        "Action is the foundational key to all success.",
        "You may delay, but time will not.",
        "Amateurs sit and wait for inspiration. The rest of us just get up and go to work.",
        "The secret of getting ahead is getting started.",
        "Discipline is choosing between what you want now and what you want most.",
        "A year from now you may wish you had started today.",
        "Done is better than perfect.",
        "How you do anything is how you do everything.",
        "Motivation gets you going, habit keeps you showing up.",
        "The meeting you dread is rarely as hard as the dread itself.",
        "Show up. That's the whole secret.",
        "Future you is watching what you do next."
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
        playSound("Glass")

        // Safety fallback: never leave the screens locked for more than 30 seconds
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.dismissAll()
        }
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
                playSound("Hero")
                dismissAll()
                return
            }
        } else {
            typedCount = 0
            playSound("Basso")
        }

        for view in contentViews {
            view.update(typedCount: typedCount)
        }
    }

    private func playSound(_ name: String) {
        NSSound(named: name)?.play()
    }

    func dismissAll() {
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
