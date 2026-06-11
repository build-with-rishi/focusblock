# FocusBlock

**The meeting starts with or without you. Be there.**

FocusBlock interrupts you before a calendar event starts — hard enough that you
can't ignore it. At 30, 10, and 5 minutes before each event it takes over your
screen with a black overlay, loops a native alarm ringtone, shows a direct
anti-procrastination quote, and makes you **type a challenge word** to dismiss
it. A wrong letter resets your progress. No snooze button, no reflexive swipe.

No accounts, no API keys, no analytics, no network calls (except the optional
ICS feed on Windows), no third-party dependencies on any platform.

## Platforms

| Platform | Folder | Calendar source | Status |
|----------|--------|-----------------|--------|
| macOS    | [`macos/`](macos/) | EventKit (native Calendar, incl. synced Google) | Reference implementation, actively used |
| Windows  | [`windows/`](windows/) | ICS subscription URL (e.g. Google secret iCal address) | Port, needs testers |
| Android  | [`android/`](android/) | CalendarContract (native calendar, incl. synced Google) | Port, needs testers |
| iOS      | [`ios/`](ios/) | EventKit + time-sensitive notifications | Port, needs testers — see iOS limitations in its README |

Each folder is a self-contained project with its own README and build
instructions. The macOS app is the reference: behavior questions are settled
by what `macos/` does.

## How it works (all platforms)

1. Reads upcoming events from the platform's calendar.
2. At 30 / 10 / 5 minutes before an event (each window toggleable), shows a
   full-screen black challenge screen: event title, a **huge** time-to-event,
   start time and duration, and a random quote like
   *"Stop negotiating with yourself. Wrap up and show up."*
3. A native alarm ringtone loops until you type the random challenge word
   (FOCUS, COMMIT, ARRIVE, …). Wrong letter → progress resets.
4. Safety fallback: the screen auto-releases after 30 seconds, so a stuck
   keyboard can never lock you out.

## Google Calendar

FocusBlock deliberately avoids the Google Calendar API and OAuth. Sync your
Google calendar to the OS instead:

- **macOS / iOS:** add your Google account under System Settings / Settings >
  Internet Accounts and enable Calendars — or subscribe to the calendar's
  public/secret ICS link in Apple Calendar.
- **Android:** the Google account on the device already syncs to the native
  calendar provider.
- **Windows:** paste your Google Calendar's "Secret address in iCal format"
  into the tray menu.

## Contributing

Contributions are welcome — especially testing and fixes for the Windows,
Android, and iOS ports, which were written faithful-to-reference but need
real-device validation. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Versioning

This repo uses [Semantic Versioning](https://semver.org/) with a single
version for the whole project, tagged `vX.Y.Z` on `main`. See
[CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
