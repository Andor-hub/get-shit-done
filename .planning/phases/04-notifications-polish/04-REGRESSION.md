# HabitX 2.0 - TestFlight Regression Checklist

**IMPORTANT: These tests MUST be performed on a Physical Device, not the iOS Simulator.**
The Simulator does not reproduce widget interactivity, App Groups provisioning, or notification delivery behavior.

**Target build:** TestFlight (Ad Hoc or App Store distribution, NOT Debug builds)
**Minimum device requirement:** iPhone running iOS 17.0+

---

## Phase 3 Deferred Tests (Widget Interactivity — Physical Device Only)

These tests cannot be verified in the Simulator. WidgetKit interactive buttons require real hardware.

- [ ] Boolean habit widget: tap toggles done/undone, widget updates without opening the app
- [ ] Count habit widget: tap increments count by 1, widget updates without opening the app
- [ ] Input habit widget: tap opens app to NumberInputSheet for that habit
- [ ] After a widget interaction, open the app -- Today view shows the updated state (not stale data)
- [ ] Deep-link via `habitx://` URL opens the correct habit's input sheet in the app

---

## Phase 4 Notification Tests (Physical Device Only)

Local notifications cannot be delivered in the Simulator environment; all notification tests require a real device.

- [ ] Create a new habit, enable the Remind me toggle, set a reminder time -- notification fires at the configured time
- [ ] Notification shows only the habit name as title with no body text and no coaching language
- [ ] Disable the reminder toggle for a habit and save -- no notification fires at the previously set time
- [ ] Enable the Remind me toggle on the very first habit ever created -- the iOS system permission dialog appears
- [ ] Deny the notification permission in the system dialog -- the toggle reverts to OFF and an inline "Enable notifications in Settings to receive reminders." caption appears below the toggle
- [ ] Complete a habit for today, send the app to the background, then bring it back to the foreground -- the pending notification for that completed habit is cancelled (verify via Settings > Notifications or by waiting past the reminder time)
- [ ] Verify a notification does NOT fire for a habit that has already been completed today

---

## General Regression

These tests should be verified on every TestFlight build regardless of which phase was changed.

- [ ] App launches without crash on a physical device
- [ ] Boolean habit: can be created, toggled done, and toggled undone
- [ ] Count habit: can be created, incremented, and decremented
- [ ] Input habit: can be created, and a numeric value can be entered via NumberInputSheet
- [ ] History view shows correct completion data for past days
- [ ] Stats view shows correct streak and completion rate data
- [ ] Empty state displays correct copy in Today view when no habits exist: "No habits yet -- tap + to add your first one"
- [ ] Empty state displays correct copy in History view when no habits exist
- [ ] Empty state displays correct copy in Stats view when no habits exist

---

*Last updated: Phase 04 — notifications-polish*
