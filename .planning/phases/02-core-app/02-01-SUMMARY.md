---
phase: 02-core-app
plan: 01
subsystem: data-services
tags: [swiftdata, swift-testing, habit-log, stats, tdd]
dependency_graph:
  requires: [01-foundation/01-02]
  provides: [HabitLogService, StatsCalculator, HabitDefaults, HabitXTests-target]
  affects: [02-02, 02-03, 02-04]
tech_stack:
  added: [Swift Testing framework, HabitXTests target]
  patterns: [upsert-log-per-day, pure-stats-functions, calendar-startOfDay-boundary]
key_files:
  created:
    - HabitX/HabitX/Services/HabitLogService.swift
    - HabitX/HabitX/Utilities/StatsCalculator.swift
    - HabitX/HabitX/Utilities/HabitDefaults.swift
    - HabitX/HabitXTests/StatsCalculatorTests.swift
    - HabitX/HabitXTests/HabitLogServiceTests.swift
    - HabitX/HabitXTests/HabitXTests.entitlements
  modified:
    - HabitX/HabitX/Models/SharedModelContainer.swift
    - project.yml
    - HabitX.xcodeproj/project.pbxproj
decisions:
  - "HabitLogService uses static functions (enum namespace) — no instance state needed; ModelContext passed per call"
  - "StatsCalculator uses completedDaySet helper that deduplicates and groups logs by calendar day before comparing to dailyTarget"
  - "SharedModelContainer falls back to default documents directory when App Group container is unavailable — enables unit test runner without provisioning"
  - "Test entitlements file added for HabitXTests target with App Group identifier for SharedModelContainer fallback detection"
  - "appAccent color defined as Color extension (static let appAccent) rather than a top-level constant — follows Swift API guidelines"
metrics:
  duration: ~30 min
  completed_date: "2026-03-29"
  tasks_completed: 2
  files_created: 6
  files_modified: 3
---

# Phase 02 Plan 01: Data Services and Business Logic Summary

**One-liner:** HabitLogService upsert pattern + pure StatsCalculator streak/rate functions + HabitDefaults templates, tested with Swift Testing (27 tests pass).

## What Was Built

### HabitLogService (HabitX/HabitX/Services/HabitLogService.swift)

All write operations for habit logging follow a one-log-per-day upsert pattern using `Calendar.current.startOfDay(for: Date())` for timezone-correct date boundaries (LOG-04 compliance). Functions are `@MainActor` since `ModelContext` is not `Sendable`.

Exported functions:
- `toggleBoolean(habit:context:)` — creates or deletes today's log
- `incrementCount(habit:context:)` — increments or creates today's log
- `setValue(habit:value:context:)` — replaces or creates today's log with a specific value
- `todayValue(for:)` — read-only; sums today's log values without ModelContext
- `isCompleted(habit:)` — read-only; `todayValue >= dailyTarget`

### StatsCalculator (HabitX/HabitX/Utilities/StatsCalculator.swift)

Pure functions — no ModelContext, no `@MainActor`, fully testable in isolation. Core logic uses a `completedDaySet` helper that groups log values by `startOfDay`, sums them, and retains only days where total >= `dailyTarget`.

Exported functions:
- `currentStreak(for:)` — counts from today (if completed) or yesterday backward
- `bestStreak(for:)` — scans sorted completed days for longest consecutive run
- `completionRate30Days(for:)` — shortcut for `completionRate(for:days:30)`
- `completionRate(for:days:)` — fraction of last N days completed
- `completionByDay(for:days:)` — array of (date, Bool) for chart rendering

### HabitDefaults (HabitX/HabitX/Utilities/HabitDefaults.swift)

Value-type `HabitTemplate` struct (`Sendable`) with two pre-defined templates:
- `proteinTemplate`: name="Protein", type=.input, target=150.0, unit="g"
- `waterTemplate`: name="Water", type=.count, target=8.0, unit="cups"
- `defaultHabits: [HabitTemplate]` convenience array
- `createHabit(from:sortOrder:)` — free function that instantiates a Habit from a template
- `Color.appAccent` — teal `Color(red: 0.0, green: 0.6, blue: 0.7)` as Color extension

### Tests (HabitXTests target)

27 tests across 2 suites using Swift Testing `@Test` / `#expect`:
- `StatsCalculatorTests`: 17 tests covering streak edge cases (empty, gaps, in-progress today, best-in-past), completion rate, completionByDay
- `HabitLogServiceTests`: 10 tests covering toggle/increment/setValue upsert behavior, todayValue, isCompleted

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] SharedModelContainer fatal crash in test runner**

- **Found during:** Task 2 test execution
- **Issue:** `SharedModelContainer.container` called `groupContainer: .identifier("group.com.habitx.shared")` which produces a fatal error when the App Group sandbox container is not provisioned (unit test runner environment).
- **Fix:** Replaced `groupContainer: .identifier(...)` with an explicit `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` check. Falls back to default documents directory when App Group not available. This is transparent at runtime on a provisioned device.
- **Files modified:** `HabitX/HabitX/Models/SharedModelContainer.swift`
- **Commit:** 5fd2173

**2. [Rule 3 - Blocking] HabitXTests target missing from project.yml**

- **Found during:** Task 2 (plan correctly anticipated this — "Check if project.yml has a test target. If not, add one.")
- **Fix:** Added `HabitXTests` target to `project.yml` with `bundle.unit-test` type, App Group entitlement, and `HabitX` dependency. Ran `xcodegen generate`.
- **Files modified:** `project.yml`
- **Commit:** 5fd2173

### Simulator Compatibility Note

The `xcodebuild test` run emits CoreData "Failed to stat path" log lines in the simulator — these are cosmetic warnings from the new fallback path being created for the first time. Tests run and pass cleanly; no test failures or assertion errors.

## Verification

1. `xcodebuild build` succeeds for HabitX target — BUILD SUCCEEDED
2. All 27 unit tests pass — `Test run with 27 tests in 2 suites passed after 0.217 seconds`
3. `Calendar.current.startOfDay` used in all date boundaries in HabitLogService (4 occurrences)
4. StatsCalculator has no `ModelContext` parameter — confirmed pure functions

## Known Stubs

None — all service functions are fully wired. No placeholder data.

## Self-Check: PASSED

All created files exist on disk. Both task commits (8fe5310, 5fd2173) verified in git log.
