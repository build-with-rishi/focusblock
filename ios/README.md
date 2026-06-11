# FocusBlock for iOS

A minimal iOS port of the macOS FocusBlock menu-bar agent. It reads your
calendar and confronts you at 30 / 10 / 5 minutes before each event with a
black full-screen challenge: a huge countdown, a direct anti-procrastination
quote, and a random word you must type letter-by-letter (a wrong letter resets
your progress) while an alarm tone loops. There is a 30-second auto-dismiss
fallback so the screen is never held hostage.

## iOS limitations (read this first)

The macOS app throws an unmissable overlay across **all screens**, on top of
whatever you are doing. **iOS does not allow that.** Third-party iOS apps
cannot draw over other apps, cannot block the screen system-wide, and cannot
run a continuous background polling loop. The faithful iOS translation is:

- **Local notifications instead of overlays.** Each time the app runs (in the
  foreground, or during an opportunistic `BGAppRefreshTask`), it reads the
  next 48 hours of events with EventKit and schedules a local notification
  per event per enabled window using `UNCalendarNotificationTrigger` anchored
  to the event's start date. Delivery is handled by the system, so it works
  even if the app never runs again — it does **not** depend on background
  polling, which iOS forbids.
- **The challenge runs inside the app's own screen.** When you open the app
  (from the notification or otherwise) while an event is within an enabled
  trigger window (window ± 1 minute, same logic as the macOS poller), the app
  takes over its own UI with the full-screen challenge. Each `(eventID,
  window)` pair fires once, deduplicated through UserDefaults.
- **Time-sensitive interruption level.** Notifications request
  `.timeSensitive` so they break through Focus modes — but true time-sensitive
  delivery also requires the *Time Sensitive Notifications* capability on your
  app ID (Signing & Capabilities → "+ Capability"). Without it, iOS quietly
  downgrades them to normal notifications.
- **Alarm sound.** No audio file is bundled, so `AVAudioPlayer` is not an
  option. The looping alarm is approximated with
  `AudioServicesPlaySystemSound(1005)` (the classic `alarm.caf`) re-fired by a
  timer. Known limitations: it respects the hardware silent switch and cannot
  match a real ringtone's volume behavior.
- **`BGAppRefreshTask` is opportunistic.** iOS decides when (typically a few
  times a day) and offers no guarantees. It is used only to re-anchor the
  pending notifications to fresh calendar data, never for alert delivery.

Google Calendar works the same way it does on macOS: add the Google account
in iOS **Settings → Apps → Calendar → Calendar Accounts** (or Settings →
Mail/Accounts on older versions) and its events appear in the native calendar
that EventKit reads.

## Requirements

- Xcode 15 or later (iOS 17 SDK). The Command Line Tools alone are not enough.
- iOS 17.0+ device or simulator.
- An Apple ID added to Xcode for automatic signing (a free account works for
  running on your own device).

## Build & run

1. Open the project:
   ```
   open ios/FocusBlock.xcodeproj
   ```
2. Select the **FocusBlock** target → **Signing & Capabilities**, check
   **Automatically manage signing**, and pick your **Team** (your Apple ID).
   Xcode may ask you to change the bundle identifier
   (`com.rishi.focusblock.ios`) to something unique to your team — that's fine.
3. (Optional but recommended) Click **+ Capability** and add
   **Time Sensitive Notifications** so alerts break through Focus modes.
4. Choose a simulator or your plugged-in iPhone as the run destination and
   press **Run** (Cmd-R).
5. On a physical device with a free Apple ID, you must also trust the
   developer certificate the first time: Settings → General → VPN & Device
   Management → your Apple ID → Trust.

Command-line build (after signing is configured in Xcode once):

```
xcodebuild -project ios/FocusBlock.xcodeproj -scheme FocusBlock \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Permission flow

1. First launch shows the status screen with **Calendar** and
   **Notifications** marked "Not granted".
2. Tap **Grant Access**:
   - iOS asks for **Full Calendar Access** (required so the app can read event
     titles and times; the usage string is in `Info.plist`).
   - iOS asks for **Notification** permission (alerts + sound).
3. If you decline either prompt, the buttons stay visible and **Open
   Settings** deep-links to the app's settings page where you can grant them
   later.
4. Use **Test Challenge** to preview the full-screen challenge with a mock
   event — type the displayed word to dismiss it (wrong letters reset
   progress with an error haptic), or wait 30 seconds for the auto-dismiss.

## Day-to-day use

- Leave the 30/10/5 toggles set to taste; notifications are (re)scheduled
  immediately whenever a toggle changes or the app comes to the foreground.
- When a notification fires, open it. If the event is still inside the
  trigger window, the black challenge screen appears: event title, huge
  countdown to start, start time · duration, a quote, and the challenge word.
  Type the word to dismiss.

## Files

```
ios/
├── FocusBlock.xcodeproj/project.pbxproj   Hand-written minimal project
├── FocusBlock/
│   ├── FocusBlockApp.swift    App entry, scenePhase refresh, BG task + notification delegate
│   ├── CalendarScheduler.swift EventKit + notification scheduling + trigger-window detection
│   ├── ChallengeView.swift    Full-screen challenge UI (hidden TextField keyboard input)
│   ├── ContentView.swift      Status screen: permissions, next event, toggles, test button
│   ├── Quotes.swift           20 quotes + 10 challenge words (verbatim from macOS)
│   └── Info.plist             Calendar usage string, BG task IDs, background fetch mode
└── README.md
```
