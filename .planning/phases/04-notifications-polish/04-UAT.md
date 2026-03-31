---
status: complete
phase: 04-notifications-polish
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md]
started: 2026-03-31T00:00:00Z
updated: 2026-03-31T00:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. App Builds and Launches
expected: Build and run on Simulator. App opens to the Today tab with existing habits intact. No crash, no regression from Phase 3.
result: pass

### 2. Reminders Section in HabitFormView
expected: Tap any existing habit to open its edit form (or create a new one). After the Target section, a "Reminders" section appears with a single "Remind me" toggle row. The toggle is OFF by default for habits with no reminder set.
result: pass

### 3. Toggle ON Shows DatePicker
expected: Tap the "Remind me" toggle to turn it ON. A "Time" DatePicker appears inline below the toggle showing 8:00 AM (or the previously saved time if editing an existing reminder). The picker lets you select hour and minute.
result: pass

### 4. Toggle OFF Hides DatePicker
expected: With the toggle ON and DatePicker visible, tap the toggle again to turn it OFF. The DatePicker disappears immediately. Saving the form with toggle OFF clears any previously saved reminder time.
result: pass

### 5. Reminder Time Persists After Save
expected: Open a habit edit form, enable the reminder toggle, set a specific time (e.g. 9:30 AM), and save. Re-open the same habit's edit form. The Reminders toggle is ON and the time picker shows 9:30 AM — the value was written to the model and reloaded correctly.
result: pass

### 6. Notification Permission — First Toggle Enable
expected: On a fresh install with notification permission not yet granted — open a habit edit form and turn ON the "Remind me" toggle. The iOS system permission dialog ("HabitX would like to send you notifications") appears immediately. Accepting enables the toggle and saves normally.
result: pass

### 7. Denied Permission Shows Inline Caption
expected: With notification permission denied in Settings — open a habit edit form and attempt to turn ON the "Remind me" toggle. The toggle immediately reverts to OFF, and a small grey caption appears: "Enable notifications in Settings to receive reminders." No modal, no alert.
result: pass

### 8. Foreground Cancellation for Completed Habits
expected: Set a reminder for a habit. Log the habit as completed for today. Background the app, then bring it back to foreground. The completed habit's pending notification is cancelled so it does not fire later that day.
result: pass

### 9. Notification Fires at Scheduled Time
expected: Set a reminder for a habit at a time 1-2 minutes in the future. Lock the device or background the app. At the scheduled time, a notification appears showing only the habit name as the title with no body text, no badge, and the default sound. Tapping it opens HabitX.
result: pass

### 10. TodayView Empty State
expected: Delete all habits (or test on a fresh install / after clearing data). Open the Today tab. Instead of a blank list, a centered prompt reads "No habits yet -- tap + to add your first one" (or similar action-oriented copy). The + button in the nav bar is still accessible.
result: pass

### 11. HistoryListView Empty State
expected: With no habits in the app — navigate to the History tab. Instead of a blank list, an empty state message appears directing users to add habits from the Today tab (e.g., "Add habits from the Today tab to see history here.").
result: pass

### 12. StatsListView Empty State
expected: With no habits in the app — navigate to the Stats tab. Instead of a blank list, an empty state message appears directing users to the Today tab (e.g., "Add habits from the Today tab to see stats here.").
result: pass

## Summary

total: 12
passed: 12
issues: 0
pending: 0
blocked: 0
skipped: 0

## Gaps

[none yet]
