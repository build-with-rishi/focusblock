# Challenge Overlay — Design

**Date:** 2026-06-10
**Status:** Approved by user

## Problem

The overlay was trivially skippable: any key or click dismissed it, and it
auto-dismissed after 8 seconds. The user wants real friction before a meeting —
sound, a typed challenge, and an anti-procrastination quote — so the reminder
can't be reflexively swatted away.

Calendar source note: the user subscribed to their Google Calendar via its
public ICS link in Apple Calendar, so EventKit already sees the events. No
Google API integration is needed or wanted.

## Behavior

When an overlay triggers (real event or Test Overlay):

1. **Sound** — a native macOS alert sound (`NSSound(named: "Glass")`) plays on
   show. A wrong keystroke plays "Basso". Completing the challenge plays
   "Hero". No bundled audio; system sounds only.
2. **Quote** — one quote is chosen at random from a bundled list of ~15
   anti-procrastination quotes and rendered on the overlay. No network.
3. **Typed challenge** — a random word is chosen from a built-in list
   (FOCUS, COMMIT, BEGIN, ARRIVE, PRESENT, DELIVER, ENGAGE, PREPARE, …).
   The overlay shows the word spaced out with per-letter progress. The user
   must type it to dismiss. A wrong letter resets progress. Non-letter keys
   (arrows, Esc, modifiers) are ignored — they neither advance nor reset.
   Clicks do nothing. Any-key dismissal is removed.
4. **Safety fallback** — the overlay auto-dismisses after 30 seconds
   (was 8), so a hardware/input failure can never lock all screens.

## Architecture

Only three files change:

- `OverlayWindowController.swift` — owns the challenge state (word, typed
  count, quote), picks the random word/quote, plays sounds, routes keystrokes,
  updates all screens' content views, runs the 30 s fallback timer.
- `OverlayWindow.swift` — no longer dismisses on input; forwards `keyDown`
  events to the controller via an `onKeyEvent` closure. `mouseDown` override
  removed.
- `OverlayContentView.swift` — renders the quote (wrapped, centered) and the
  challenge word with typed letters bright / remaining letters dim, plus a
  "type the word to dismiss" hint. Gets an `update(typedCount:)` method.

Multi-monitor: every screen gets its own window+view as before; only the key
window receives keystrokes, but all views render from the controller's single
challenge state, so progress shows on all screens simultaneously.

Unchanged: EventKit polling, 30/10/5-minute trigger windows, menu bar UI,
LSUIElement, no dock icon, no network, no third-party dependencies.

## Decisions made with the user

- Random word per overlay (not a fixed keyword, not the event title).
- 30-second auto-dismiss fallback (user shortened from proposed 90 s).
