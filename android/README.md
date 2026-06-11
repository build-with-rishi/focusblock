# FocusBlock for Android

A minimal Android port of the macOS FocusBlock menu-bar app. It watches the
device's native calendar (Google Calendar accounts sync into it automatically)
and, at 30/10/5 minutes before each upcoming event, fires a full-screen,
hard-to-skip interruption: event title, a huge "10 minutes" countdown label,
start time and duration, one anti-procrastination quote, and a random
challenge word (FOCUS, COMMIT, ...) that you must type to dismiss. A native
alarm ringtone loops the whole time; a wrong letter resets your progress and
plays an error tone. A 30-second auto-dismiss is the safety fallback.

- Package: `com.rishi.focusblock`, versionName 1.0.0, versionCode 1
- Kotlin, classic Views + XML layouts, no Compose
- Dependencies: only `androidx.core` and `androidx.appcompat` (no third-party libraries)
- minSdk 26, targetSdk/compileSdk 34, AGP 8.2.2, Kotlin 1.9.22, Gradle Kotlin DSL

## Project layout

```
android/
├── build.gradle.kts            # root: plugin versions
├── settings.gradle.kts
├── gradle.properties
└── app/
    ├── build.gradle.kts
    └── src/main/
        ├── AndroidManifest.xml
        ├── java/com/rishi/focusblock/
        │   ├── MainActivity.kt        # permissions, window toggles, next event, test button
        │   ├── MonitorService.kt      # foreground service, 60 s calendar poll, triggers
        │   ├── OverlayActivity.kt     # full-screen interruption + challenge + alarm
        │   ├── CalendarRepository.kt  # CalendarContract.Instances queries
        │   └── Prefs.kt               # window toggles + per-trigger dedup store
        └── res/                       # layouts, strings, themes, vector icons
```

## Building

**Note:** the Gradle wrapper JAR is a binary and is intentionally not included
in this repo. Use one of the options below.

### Android Studio (recommended)

1. Open Android Studio (Hedgehog 2023.1.1 or newer, with JDK 17) and choose
   **Open**, then select this `android/` folder.
2. Android Studio generates the Gradle wrapper, downloads Gradle/AGP, and
   syncs the project.
3. Press **Run** to install on a connected device or emulator (API 26+).

### Command line

You need JDK 17 and either a local Gradle 8.2+ install or a one-time wrapper
generation:

```bash
cd android
gradle wrapper --gradle-version 8.4   # one-time, needs a local Gradle install
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

Set the SDK location first if Gradle can't find it: create
`android/local.properties` with `sdk.dir=/path/to/Android/sdk`, or export
`ANDROID_HOME`.

## First-run walkthrough (permissions)

1. **Grant permissions** button → grants:
   - `READ_CALENDAR` — to query upcoming events.
   - `POST_NOTIFICATIONS` (Android 13+) — for the foreground-service
     notification and the full-screen alert notification.
2. The monitor service starts automatically once calendar access is granted.
   A persistent low-priority notification ("FocusBlock is watching your
   calendar") is required by Android for foreground services.
3. **Battery optimization settings** button → find FocusBlock and choose
   "Don't optimize" / "Unrestricted". Strongly recommended (see caveats).
4. On Android 14+, if full-screen alerts are not allowed, an extra
   **Allow full-screen alerts** button appears and deep-links to the system
   toggle (see caveats).
5. **Test overlay** fires the interruption immediately with a fake
   "Test Event" so you can try the typing challenge and the alarm.

Toggle which alert windows (30/10/5 minutes before) are active with the
checkboxes; the choice is stored in SharedPreferences and read on every poll.

## Design decisions

- **Foreground service with `specialUse` type.** targetSdk 34 requires every
  foreground service to declare a type. None of the enumerated types fits
  "poll the local calendar provider to interrupt the user":
  `dataSync` is for network data transfer and gets hard time limits from
  Android 15, `shortService` is capped at ~3 minutes, and the rest
  (camera, location, mediaPlayback, ...) are obviously wrong. `specialUse` is
  the documented escape hatch and carries a
  `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` explanation in the manifest. (For Play
  Store distribution this requires a declaration during review; for personal
  side-loading it just works.)
- **Polling, not alarms.** The service checks `CalendarContract.Instances`
  for the next 35 minutes once per minute, mirroring the macOS app's
  60-second timer. A trigger fires when an event starts within ±1 minute of
  an enabled window (30/10/5), the same tolerance as the macOS version.
- **Per-trigger dedup** uses keys of `eventId|instanceBeginMs|windowMinutes`
  persisted in SharedPreferences, so each (event instance, window) pair fires
  exactly once even across service restarts. Old entries are pruned 2 hours
  after the event start. Using the instance begin time means each occurrence
  of a recurring event gets its own triggers.
- **Full-screen intent, not a system overlay.** Android has no equivalent of
  macOS's "borderless window above everything" for normal apps. The closest
  sanctioned mechanism is a high-priority notification with a full-screen
  `PendingIntent` (`USE_FULL_SCREEN_INTENT`), the same mechanism alarm-clock
  apps use. The overlay activity sets `showWhenLocked`/`turnScreenOn`, blocks
  the back gesture, and is excluded from recents.
- **The alert notification channel is silent**; `OverlayActivity` itself loops
  the device's default **ALARM** ringtone via `MediaPlayer` with
  `USAGE_ALARM` audio attributes (so it respects alarm volume, not media
  volume) and stops it the instant the challenge is solved. Wrong letters
  play `ToneGenerator.TONE_SUP_ERROR` on the alarm stream.
- **Challenge input** is an invisible 1dp `EditText` that holds focus; a
  `TextWatcher` consumes each character (works with both soft and hardware
  keyboards), and the word is rendered as a single `TextView` with wide
  `letterSpacing` and per-letter `ForegroundColorSpan`s (white for typed,
  dim gray for pending). The soft keyboard is forced visible and re-shown on
  tap if dismissed.
- **Quotes and challenge words** are copied verbatim from the macOS
  `OverlayWindowController.swift` (20 quotes, 10 words).

## Honest caveats

- **Battery optimization / OEM task killers.** Android may stop the
  foreground service under Doze or OEM "battery saver" policies (Samsung,
  Xiaomi, OnePlus are aggressive). Excluding the app from battery
  optimization helps a lot but is not a guarantee. The service is
  `START_STICKY`, so the system restarts it when it can, but a killed service
  means missed polls. There is no scheduled-restart mechanism in this minimal
  port (no WorkManager, by design — zero third-party-ish machinery).
- **Full-screen intents on Android 14+.** `USE_FULL_SCREEN_INTENT` is granted
  by default only to apps whose core function is alarms/calls when installed
  from the Play Store; side-loaded/Studio installs get it by default. If
  revoked, the app shows a button that deep-links to the system toggle
  (`Settings > Apps > FocusBlock > Allow full-screen notifications`). Without
  it, the alert degrades to a heads-up notification you must tap.
- **Screen-on behavior.** Even with the permission, Android launches the
  full-screen activity automatically only when the screen is off or the
  keyguard is showing. If you're actively using the phone, the system shows a
  heads-up notification instead; tapping it opens the overlay. This is an OS
  rule, not something an app can override.
- **No system-wide overlay like macOS.** On macOS, FocusBlock floats above
  every space and screen and can swallow all keystrokes. Android intentionally
  forbids that: the Home gesture, quick settings, and the notification shade
  always work, so a determined user can leave the overlay (the alarm stops
  when the activity is destroyed, and the 30-second fallback bounds the
  interruption anyway).
- **Calendar sync lag.** The app reads the on-device calendar provider. A
  brand-new Google Calendar event appears only after the account syncs
  (usually within minutes). Events created on-device show up immediately.
- **All-day events are skipped** on purpose (they "start" at midnight and
  pre-event interruptions make no sense for them).
