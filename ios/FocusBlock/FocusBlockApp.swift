import BackgroundTasks
import SwiftUI
import UserNotifications

@main
struct FocusBlockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scheduler = CalendarScheduler.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scheduler)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Foreground refresh: re-read the calendar, re-anchor all
                // pending notifications, and present the challenge if an
                // event is inside a trigger window right now.
                Task { await scheduler.refresh() }
            case .background:
                CalendarScheduler.scheduleAppRefresh()
            default:
                break
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // BGTaskScheduler handlers must be registered before the app finishes
        // launching. The refresh task only re-schedules notifications from the
        // latest calendar data; it is opportunistic and never relied on for
        // on-time delivery (UNCalendarNotificationTrigger handles that).
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: CalendarScheduler.backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            CalendarScheduler.shared.handleAppRefresh(refreshTask)
        }
        return true
    }

    // Show banners even while the app is foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // Tapping a notification just opens the app; the scenePhase handler in
    // FocusBlockApp then runs refresh() and fires the in-app challenge.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await CalendarScheduler.shared.refresh()
    }
}
