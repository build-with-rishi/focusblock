# Contributing to FocusBlock

Thanks for helping make meetings harder to skip.

## Ground rules

- **One purpose.** FocusBlock interrupts you before calendar events. PRs that
  add unrelated features (todo lists, pomodoro timers, stats dashboards) will
  be declined, kindly.
- **No third-party dependencies.** Every platform builds with only its native
  SDK. This is a hard constraint, not a preference.
- **No network calls** except the ICS feed fetch on Windows. No analytics,
  no telemetry, no crash reporting.
- **The macOS app is the reference.** If platform behavior is ambiguous,
  match `macos/`.

## What we most need

- Real-device testing of the **Windows**, **Android**, and **iOS** ports.
  They were written against platform documentation and need validation —
  bug reports with logs are gold.
- Multi-monitor edge cases on macOS and Windows.
- Locale/timezone correctness for event times.

## Workflow

1. Fork, branch from `main`: `git checkout -b fix/short-description`
2. Make your change inside ONE platform folder (or root docs). Cross-platform
   behavior changes should update `macos/` first plus an issue describing the
   change for other platforms.
3. Build it:
   - macOS: `cd macos && swiftc -typecheck -warnings-as-errors -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macos13.0 FocusBlock/*.swift` (or build in Xcode — zero warnings expected)
   - Windows: `cd windows && dotnet build`
   - Android: open `android/` in Android Studio, or `gradle build`
   - iOS: build in Xcode
4. Test the overlay via the app's built-in **Test Overlay** action.
5. Open a PR with: what changed, why, platform(s) affected, how you tested.

## Commit messages

Plain imperative subject lines ("Fix overlay focus on second monitor"), body
explaining why when it isn't obvious. Reference issues with `#123`.

## Releases & versioning

- [SemVer](https://semver.org/): MAJOR for behavior breaks, MINOR for new
  capability, PATCH for fixes. One version across all platforms.
- Every user-visible change adds a line under `[Unreleased]` in
  `CHANGELOG.md` — maintainers cut releases by moving that section to a
  version heading and tagging `vX.Y.Z`.

## Reporting bugs

Use the bug report issue template. Always include: OS version, how your
calendar is connected (native sync vs ICS), and what the overlay did vs what
you expected.

## Code of Conduct

Be a decent human. Reports of harassment or abuse go to the repo owner and
will be acted on. (See CODE_OF_CONDUCT.md.)
