# FocusBlock for Windows

A Windows port of FocusBlock: a tray-only app that watches your calendar and,
at **30 / 10 / 5 minutes** before each upcoming event, blocks **all connected
monitors** with a full-screen black overlay. A native alarm sound loops until
you type the random challenge word (e.g. `FOCUS`, `COMMIT`) shown on screen —
correct letters light up white, a wrong letter resets your progress with an
error sound. As a safety fallback, the overlay always auto-dismisses after
30 seconds.

## Requirements

- Windows 10 (1607+) or Windows 11
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) to build,
  or the **.NET 8 Desktop Runtime** to run a published build

No NuGet packages are used; everything is in-box (.NET 8 WPF + WinForms).

## Build & run

### Command line

```
cd windows
dotnet build -c Release
dotnet run -c Release
```

Or publish a self-contained folder you can copy anywhere:

```
dotnet publish -c Release -r win-x64 --self-contained false
```

The executable lands in `bin\Release\net8.0-windows\` (or `publish\`).

### Visual Studio

Open `windows\FocusBlock.csproj` in Visual Studio 2022 (17.8+ with the
".NET desktop development" workload) and press F5.

## Setup: connect your calendar

Windows has no universally accessible native calendar store, so FocusBlock
subscribes to an **ICS (iCal) feed URL** instead and polls it every 5 minutes.

### Google Calendar ("Secret address in iCal format")

1. Open [Google Calendar](https://calendar.google.com) in a browser.
2. Click the gear icon → **Settings**.
3. In the left sidebar under **Settings for my calendars**, click your calendar.
4. Scroll to **Integrate calendar**.
5. Copy the **Secret address in iCal format** (a `https://calendar.google.com/calendar/ical/…/basic.ics` URL).
   Keep this URL private — anyone with it can read your calendar.
6. Right-click the FocusBlock tray icon → **Set Calendar URL…** → paste → OK.

Outlook.com ("Publish calendar" → ICS link) and most other calendar services
offer an equivalent ICS subscription URL. `webcal://` URLs are accepted and
automatically converted to `https://`.

## Tray menu

Right-click the FocusBlock icon in the system tray (it may be hidden behind
the `^` overflow chevron):

- **Next: \<event> at \<time>** — your next event in the coming 24 hours
- **Test Overlay** — fire a sample overlay immediately (good for checking sound and monitors)
- **Alert Windows** — toggle the 30 / 10 / 5 minutes-before triggers
- **Set Calendar URL…** — paste your ICS subscription URL
- **Launch at Login** — registers/unregisters FocusBlock in the per-user
  registry Run key (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`)
- **Quit FocusBlock**

Settings persist to `%APPDATA%\FocusBlock\settings.json`.

## How it works

- The ICS feed is fetched every 5 minutes (`HttpClient`); a built-in minimal
  parser handles line unfolding, `DTSTART`/`DTEND` in UTC (`…Z`), `TZID=`
  time zones, all-day `VALUE=DATE` dates, and `SUMMARY` text unescaping.
- Cached events are checked every 60 seconds. Each (event UID, window) pair
  triggers **only once**, so you get at most one overlay per event per window.
- The overlay creates one borderless, topmost black window per monitor
  (positioned in physical pixels under Per-Monitor V2 DPI awareness, so mixed
  DPI setups are fully covered). The alarm loops a stock Windows sound from
  `C:\Windows\Media` (preferring `Alarm01.wav`).

## Caveats

- **Recurring events are not expanded.** The parser ignores `RRULE`, so only
  the literal `DTSTART` occurrences present in the feed will trigger.
  (Google's secret ICS feed represents a recurring series as a single event
  plus an RRULE, so later occurrences of that series won't fire.)
- **ICS feeds lag.** Google can take from minutes up to several hours to
  reflect calendar changes in the secret ICS address, and FocusBlock itself
  polls only every 5 minutes. Very recently created events may be missed.
- **Cancelled events**: `STATUS:CANCELLED` events are skipped, but only after
  the feed updates (see lag above).
- The overlay is intentionally hard to bypass (topmost, Alt+F4 blocked, click
  does nothing), but it cannot cover secure desktops (UAC prompts, Ctrl+Alt+Del,
  the lock screen) or exclusive-fullscreen games on some systems.
- Requires the **.NET 8 Desktop Runtime** on machines that didn't build from
  source (unless published self-contained with `--self-contained true`).
- The dedup memory of fired triggers is kept in RAM only; restarting the app
  within a trigger window can re-fire an overlay for the same event.
