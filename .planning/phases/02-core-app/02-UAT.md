---
status: complete
phase: 02-core-app
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md, 02-03-SUMMARY.md, 02-04-SUMMARY.md]
started: 2026-03-30T13:59:19Z
updated: 2026-03-30T13:59:19Z
---

## Current Test

## Current Test

[testing complete]

## Tests

### 1. App Launches to Today Tab
expected: Build and run on Simulator. App opens directly to the Today tab. No crash, no error overlay. If no habits exist, an empty state with an Add button is visible.
result: pass

### 2. Add Protein via Template Picker
expected: Tap the + button. A sheet appears with Protein, Water, and Custom options. Selecting Protein opens a form pre-filled with name="Protein", type=Input, target=150, unit="g". Tapping Save adds it to the Today list.
result: pass

### 3. Log an Input Habit (Protein)
expected: Tap the + button on the Protein card. A number input sheet appears. Enter 50 and confirm. The card updates to show "50 / 150 g" (or similar partial state). The habit does NOT show as complete yet.
result: pass

### 4. Add Water via Template Picker
expected: Tap + to open the template picker, select Water. Form pre-fills with name="Water", type=Count, target=8, unit="cups". Tapping Save adds it to the Today list.
result: pass

### 5. Log a Count Habit (Water)
expected: Tap the + button on the Water card. Count increments by 1. Tapping 8 times (or until target is reached) changes the card to a completed state with distinct accent styling.
result: pass

### 6. Completed Habit Visual State
expected: A completed habit card looks visually distinct — accent color background tint, checkmark or similar indicator. Incomplete habits look different (no tint). The distinction is immediately obvious.
result: pass

### 7. Reorder Habits
expected: Tap Edit (or long-press). Drag handles appear. Dragging Protein above Water reorders them. Exiting edit mode preserves the new order. Re-launching the app shows the same order.
result: pass

### 8. Edit a Habit
expected: In edit mode (or via swipe), tap Edit on Protein. A form sheet opens with current values. Change the target to 120, tap Save. The Protein card now shows the new target.
result: pass

### 9. Delete a Habit
expected: Swipe a habit card left and tap Delete, or use edit mode. A confirmation dialog appears. Confirming removes the habit from the Today list permanently.
result: pass

### 10. History Tab — Per-Habit 90-Day Drill-Down
expected: Tap the History tab. A list of all habits appears. Tap a habit you've logged today. A 90-day view opens showing today at the top with the logged value. Days with no entry show "No entry" (not hidden). The display correctly reflects the habit type (e.g., "50 / 150 g" for Protein, "3 / 8 cups" for Water).
result: pass

### 11. Stats Tab — Streak and Chart
expected: Tap the Stats tab. All habits are listed with a streak preview. Tap a habit. Three stat cards appear (Current Streak, Best Streak, 30-Day Rate). A 30-day bar chart shows completed days in teal/accent and missed days in neutral gray — no red or penalty colors anywhere.
result: pass

## Summary

total: 11
passed: 11
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
