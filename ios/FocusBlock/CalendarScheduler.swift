import BackgroundTasks
import EventKit
import Foundation
import SwiftUI
import UserNotifications

// One pending in-app challenge. The word and quote are chosen when the
// challenge is created so SwiftUI re-renders never re-randomize them.
struct ChallengeRequest: Identifiable, Equatable {
    let id = UUID()
    let eventTitle: String
    let startDate: Date
    let endDate: Date
    let window: Int // 30, 10, or 5 minutes before
    let challengeWord: String
    let quote: String
}

struct EventSummary: Equatable {
    let title: String
    let startDate: Date
}

// iOS reality check: an app cannot poll the calendar continuously in the
// background the way the macOS agent does, and it cannot draw over other
// apps. So this class does two things instead:
//
//  1. Whenever the app is foregrounded (or a BGAppRefreshTask fires), it
//     schedules LOCAL NOTIFICATIONS directly from event start dates using
//     UNCalendarNotificationTrigger — the system delivers them on time even
//     if the app never runs again.
//  2. When the app becomes active while an event is inside a trigger window
//     (30/10/5 min, +/- 1 min like the macOS poller), it publishes a
//     ChallengeRequest that takes over the app's OWN screen.
@MainActor
final class CalendarScheduler: ObservableObject {
    static let shared = CalendarScheduler()
    static let backgroundTaskIdentifier = "com.rishi.focusblock.ios.refresh"

    private let store = EKEventStore()

    @Published var calendarAccessGranted = false
    @Published var notificationsAuthorized = false
    @Published var nextEvent: EventSummary?
    @Published var activeChallenge: ChallengeRequest?

    // Which time windows are enabled (30, 10, 5 minutes before).
    @Published var enabledWindows: Set<Int> {
        didSet {
            UserDefaults.standard.set(Array(enabledWindows), forKey: Keys.enabledWindows)
            Task { await self.scheduleEventNotifications() }
        }
    }

    private enum Keys {
        static let enabledWindows = "enabledWindows"
        static let shownTriggers = "shownTriggers" // ["eventID|window": fireTimestamp]
    }

    private init() {
        if let saved = UserDefaults.standard.array(forKey: Keys.enabledWindows) as? [Int], !saved.isEmpty {
            enabledWindows = Set(saved)
        } else {
            enabledWindows = [30, 10, 5]
        }
    }

    // MARK: - Permissions

    func requestAccess() async {
        calendarAccessGranted = (try? await store.requestFullAccessToEvents()) ?? false
        // .timeSensitive delivery additionally needs the Time Sensitive
        // Notifications capability on the app ID; without it, notifications
        // are silently downgraded to the default interruption level.
        notificationsAuthorized = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refresh()
    }

    private func refreshAuthorizationStatus() async {
        calendarAccessGranted = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    // MARK: - Refresh (called on every foreground + from BGAppRefreshTask)

    func refresh() async {
        await refreshAuthorizationStatus()
        guard calendarAccessGranted else { return }
        updateNextEvent()
        await scheduleEventNotifications()
        checkTriggerWindow()
    }

    private func updateNextEvent() {
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now, end: now.addingTimeInterval(24 * 3600), calendars: nil)
        let event = store.events(matching: predicate)
            .filter { $0.startDate != nil }
            .sorted { $0.startDate < $1.startDate }
            .first
        if let event, let start = event.startDate {
            nextEvent = EventSummary(title: event.title ?? "Upcoming Event", startDate: start)
        } else {
            nextEvent = nil
        }
    }

    // MARK: - Local notification scheduling

    // Schedules one notification per (event, enabled window) for the next 48h,
    // each anchored to the event's start date with UNCalendarNotificationTrigger.
    // Re-running this is idempotent: all pending requests are replaced, and the
    // identifier "eventID|window" dedups within a single pass.
    private func scheduleEventNotifications() async {
        guard calendarAccessGranted else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now, end: now.addingTimeInterval(48 * 3600), calendars: nil)
        let events = store.events(matching: predicate)
            .filter { $0.startDate != nil }
            .sorted { $0.startDate < $1.startDate }

        var scheduled = 0
        for event in events {
            guard let start = event.startDate, let eventID = event.eventIdentifier else { continue }
            for window in enabledWindows.sorted(by: >) {
                let fireDate = start.addingTimeInterval(TimeInterval(-window * 60))
                guard fireDate > now else { continue }
                // iOS keeps at most 64 pending local notifications; stay under it.
                guard scheduled < 60 else { return }

                let content = UNMutableNotificationContent()
                content.title = event.title ?? "Upcoming Event"
                content.body = "Starts in \(window) minutes. Open FocusBlock and type the word."
                content.sound = .default
                content.interruptionLevel = .timeSensitive

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(eventID)|\(window)", content: content, trigger: trigger)
                try? await center.add(request)
                scheduled += 1
            }
        }
    }

    // MARK: - In-app trigger window (same +/- 1 min logic as the macOS poller)

    private func checkTriggerWindow() {
        guard activeChallenge == nil else { return }
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now, end: now.addingTimeInterval(35 * 60), calendars: nil)
        let events = store.events(matching: predicate)
            .filter { $0.startDate != nil }
            .sorted { $0.startDate < $1.startDate }

        for event in events {
            guard let start = event.startDate, let eventID = event.eventIdentifier else { continue }
            let minutesUntil = Int(start.timeIntervalSince(now) / 60)
            // Smallest (most urgent) window wins when two overlap.
            for window in enabledWindows.sorted() {
                guard minutesUntil >= window - 1 && minutesUntil <= window + 1 else { continue }
                let key = "\(eventID)|\(window)"
                guard !shownTriggerKeys().keys.contains(key) else { continue }
                markTriggerShown(key)
                activeChallenge = ChallengeRequest(
                    eventTitle: event.title ?? "Upcoming Event",
                    startDate: start,
                    endDate: event.endDate ?? start.addingTimeInterval(3600),
                    window: window,
                    challengeWord: Quotes.challengeWords.randomElement()!,
                    quote: Quotes.all.randomElement()!
                )
                return
            }
        }
    }

    // (eventID, window) dedup persisted in UserDefaults so re-opening the app
    // inside the same window doesn't re-fire the challenge. Entries older than
    // 24h are pruned.
    private func shownTriggerKeys() -> [String: Double] {
        let stored = UserDefaults.standard.dictionary(forKey: Keys.shownTriggers) as? [String: Double] ?? [:]
        let cutoff = Date().timeIntervalSince1970 - 24 * 3600
        return stored.filter { $0.value > cutoff }
    }

    private func markTriggerShown(_ key: String) {
        var keys = shownTriggerKeys()
        keys[key] = Date().timeIntervalSince1970
        UserDefaults.standard.set(keys, forKey: Keys.shownTriggers)
    }

    // MARK: - Test challenge (mirrors OverlayWindowController.testOverlay)

    func presentTestChallenge() {
        activeChallenge = ChallengeRequest(
            eventTitle: "Test Event",
            startDate: Date().addingTimeInterval(10 * 60),
            endDate: Date().addingTimeInterval(55 * 60),
            window: 10,
            challengeWord: Quotes.challengeWords.randomElement()!,
            quote: Quotes.all.randomElement()!
        )
    }

    // MARK: - Background refresh

    // BGAppRefreshTask runs opportunistically (iOS decides when — typically a
    // few times a day, never on a guaranteed schedule). It only re-anchors the
    // pending notifications to the latest calendar data; actual alert delivery
    // never depends on this task running.
    // nonisolated: called from the nonisolated BGTask handler; touches only
    // BGTaskScheduler (thread-safe) and an immutable identifier.
    nonisolated static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    nonisolated func handleAppRefresh(_ task: BGAppRefreshTask) {
        Self.scheduleAppRefresh() // always chain the next one
        let work = Task { @MainActor in
            await self.refreshAuthorizationStatus()
            guard self.calendarAccessGranted else {
                task.setTaskCompleted(success: false)
                return
            }
            await self.scheduleEventNotifications()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
}
