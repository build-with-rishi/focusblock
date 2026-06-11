# FocusBlock for macOS

The reference implementation. A minimal menu bar app that blocks all connected
screens with a full-screen black overlay whenever a calendar event is
approaching. One job: interrupt you before a meeting starts.

- No dock icon (menu bar only)
- No third-party dependencies — EventKit + AppKit only
- Works with Google Calendar via macOS Internet Accounts sync (no API keys, no OAuth)
- Alerts at 30 / 10 / 5 minutes before each event (each window toggleable)
- Overlay covers every connected screen and sits above fullscreen apps
- Loops a native alarm ringtone until dismissed (Radar by default — pick from
  12 native tones in the menu bar's Alarm Sound submenu) and shows a random
  anti-procrastination quote
- Hard to skip: you must type the random challenge word shown on screen to
  dismiss it — a wrong letter resets your progress. Auto-dismisses after
  30 seconds as a safety fallback only.

## Build & Run (Xcode)

1. Open `FocusBlock.xcodeproj` in Xcode
2. Set signing: Xcode > Signing & Capabilities > your Apple ID
3. Build and run (Cmd+R)
4. On first launch: grant Calendar access when prompted
5. Confirm Google Calendar is synced: System Settings > Internet Accounts > Google > Calendars ON
6. App lives in menu bar only. No dock icon.
7. To test immediately: click menu bar icon > Test Overlay

## Build & Run (command line, no Xcode required)

A prebuilt, ad-hoc-signed app is already in `build/FocusBlock.app`. To rebuild:

```sh
mkdir -p build/FocusBlock.app/Contents/MacOS
swiftc -O -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos13.0" \
    FocusBlock/*.swift -o build/FocusBlock.app/Contents/MacOS/FocusBlock
sed -e 's/$(EXECUTABLE_NAME)/FocusBlock/' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.rishi.focusblock/' \
    -e 's/$(PRODUCT_NAME)/FocusBlock/' \
    -e 's/$(MACOSX_DEPLOYMENT_TARGET)/13.0/' \
    FocusBlock/Info.plist > build/FocusBlock.app/Contents/Info.plist
codesign --force --sign - build/FocusBlock.app
open build/FocusBlock.app
```

## Notes

- Requires macOS 13 (Ventura) or later.
- Calendar permission lives in System Settings > Privacy & Security > Calendars.
- Dismiss the overlay by typing the challenge word it shows; it auto-dismisses
  after 30 seconds if you walk away.
- If Google events are missing, subscribe to the calendar in Apple Calendar
  (File > New Calendar Subscription with your Google calendar's public/secret
  ICS link) or enable Calendars for your Google account in System Settings >
  Internet Accounts.
- "Launch at Login" uses Apple's `SMAppService`, so it appears under
  System Settings > General > Login Items.
