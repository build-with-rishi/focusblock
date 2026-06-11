# Changelog

All notable changes to FocusBlock are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/) with one version across all
platforms.

## [Unreleased]

## [1.0.0] - 2026-06-11

First public release.

### Added
- **macOS** (reference implementation): menu bar app, EventKit calendar
  monitoring, full-screen black overlays on every connected display at
  30/10/5 minutes before events, typed challenge-word dismissal with
  per-letter progress, looping native alarm ringtone (Radar default, picker
  with 12 native tones), 20 direct anti-procrastination quotes, 30-second
  safety auto-dismiss, Test Overlay, Launch at Login via SMAppService.
- **Windows** port: WPF tray app, ICS subscription calendar source,
  per-monitor overlays, looping Windows alarm sound, same challenge flow.
- **Android** port: foreground monitor service over CalendarContract,
  full-screen intent alarm activity with the same challenge flow.
- **iOS** port: EventKit + time-sensitive local notifications with an in-app
  challenge takeover (iOS does not allow system-wide overlays).
- Open-source packaging: MIT license, contribution guide, issue/PR templates,
  CI builds.

[Unreleased]: https://github.com/build-with-rishi/focusblock/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/build-with-rishi/focusblock/releases/tag/v1.0.0
