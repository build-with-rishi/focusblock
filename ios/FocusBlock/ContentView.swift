import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var scheduler: CalendarScheduler
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                permissionsSection
                nextEventSection
                windowsSection
                testSection

                Section {
                } footer: {
                    Text("iOS does not allow apps to block the screen system-wide. FocusBlock instead schedules time-sensitive notifications at each alert window, and shows the full-screen challenge when you open the app while an event is imminent.")
                }
            }
            .navigationTitle("FocusBlock")
        }
        .task { await scheduler.refresh() }
        .fullScreenCover(item: $scheduler.activeChallenge) { request in
            ChallengeView(request: request) {
                scheduler.activeChallenge = nil
            }
        }
    }

    // MARK: - Sections

    private var permissionsSection: some View {
        Section("Permissions") {
            statusRow(label: "Calendar", granted: scheduler.calendarAccessGranted)
            statusRow(label: "Notifications", granted: scheduler.notificationsAuthorized)

            if !scheduler.calendarAccessGranted || !scheduler.notificationsAuthorized {
                Button("Grant Access") {
                    Task { await scheduler.requestAccess() }
                }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        }
    }

    private var nextEventSection: some View {
        Section("Next Event") {
            if let event = scheduler.nextEvent {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                    Text(event.startDate, format: .dateTime.weekday(.wide).hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(event.startDate, format: .relative(presentation: .named))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No upcoming events in the next 24 hours")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var windowsSection: some View {
        Section {
            ForEach([30, 10, 5], id: \.self) { minutes in
                Toggle("\(minutes) minutes before", isOn: windowBinding(minutes))
            }
        } header: {
            Text("Alert Windows")
        } footer: {
            Text("A notification fires at each enabled window before every calendar event.")
        }
    }

    private var testSection: some View {
        Section {
            Button("Test Challenge") {
                scheduler.presentTestChallenge()
            }
        } footer: {
            Text("Previews the full-screen challenge with a mock event. Type the word to dismiss; it auto-dismisses after 30 seconds.")
        }
    }

    // MARK: - Helpers

    private func statusRow(label: String, granted: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(granted ? "Granted" : "Not granted")
                .foregroundStyle(.secondary)
        }
    }

    private func windowBinding(_ minutes: Int) -> Binding<Bool> {
        Binding(
            get: { scheduler.enabledWindows.contains(minutes) },
            set: { enabled in
                if enabled {
                    scheduler.enabledWindows.insert(minutes)
                } else {
                    scheduler.enabledWindows.remove(minutes)
                }
            }
        )
    }
}
