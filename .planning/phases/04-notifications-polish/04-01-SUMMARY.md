---
phase: 04-notifications-polish
plan: 01
subsystem: notifications
tags: [notifications, UserNotifications, HabitFormView, TabRootView, permissions]
dependency_graph:
  requires: [01-foundation, 02-core-app]
  provides: [per-habit-daily-reminders, notification-permission-flow, foreground-cancellation]
  affects: [HabitFormView, TabRootView, NotificationService]
tech_stack:
  added: [UserNotifications framework]
  patterns: [static-enum-service, contextual-permission-request, @Query-in-root-view]
key_files:
  created:
    - HabitX/HabitX/Services/NotificationService.swift
  modified:
    - HabitX/HabitX/Features/HabitForm/HabitFormView.swift
    - HabitX/HabitX/Features/Root/TabRootView.swift
    - HabitX.xcodeproj/project.pbxproj
decisions:
  - "NotificationService follows HabitLogService static enum pattern — no instance state, @MainActor for UNUserNotificationCenter thread safety"
  - "Permission requested contextually on first toggle enable, not on launch — avoids cold permission prompt"
  - "Denied state uses inline caption, not modal — non-disruptive UX"
  - "cancelRemindersForCompletedHabits is synchronous — removePendingNotificationRequests does not require async"
metrics:
  duration: 4 minutes
  completed_date: "2026-03-31"
  tasks_completed: 2
  files_modified: 4
---

# Phase 04 Plan 01: Per-Habit Daily Reminder Notifications Summary

Per-habit daily reminder notifications with contextual permission flow using UNUserNotificationCenter, a static @MainActor enum service, and foreground cancellation for completed habits.

## What Was Built

### NotificationService.swift (new)

A `@MainActor enum NotificationService` following the `HabitLogService` pattern — static methods, no stored state, all UNUserNotificationCenter operations centralized. Four methods:

- `requestAuthorizationIfNeeded()` — checks current authorization status before requesting; returns true for .authorized/.provisional, false for .denied; requests only when .notDetermined
- `scheduleReminder(for:)` — creates a repeating `UNCalendarNotificationTrigger` with title=habit.name, body="", identifier="reminder-{habit.id.uuidString}"
- `cancelReminder(for:)` — removes a single habit's pending notification by identifier
- `cancelRemindersForCompletedHabits(_:)` — filters habits with reminderTime set and today's value meeting target, removes all matching pending notifications

### HabitFormView.swift (modified)

Added three `@State` properties: `reminderEnabled`, `reminderTime` (defaults to 8:00am), `notificationsDenied`.

Added `Section("Reminders")` after the Target section with:
- `Toggle("Remind me")` bound to `reminderEnabled`
- `DatePicker("Time")` shown only when `reminderEnabled == true`
- Inline caption "Enable notifications in Settings..." shown when `notificationsDenied == true`

Added `.onChange(of: reminderEnabled)` — fires a `Task` to call `requestAuthorizationIfNeeded()`; if denied, reverts `reminderEnabled = false` and sets `notificationsDenied = true`.

Updated `onAppear` to load `habit.reminderTime` into local state.

Updated `save()` to write `reminderTime` to model and call `scheduleReminder` (or `cancelReminder` and nil out `reminderTime`).

### TabRootView.swift (modified)

Added `import SwiftData` and `@Query private var habits: [HabitSchemaV1.Habit]`.

Updated the `scenePhase == .active` handler to also call `NotificationService.cancelRemindersForCompletedHabits(habits)` alongside the existing `WidgetCenter.shared.reloadAllTimelines()`.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all notification logic is fully wired. The `reminderTime` field on `Habit` was already in the schema from Phase 01.

## Self-Check: PASSED

- `HabitX/HabitX/Services/NotificationService.swift` exists: FOUND
- Task 1 commit cfcd948: FOUND
- Task 2 commit 60e01ae: FOUND
- `xcodebuild BUILD SUCCEEDED` verified after each task
