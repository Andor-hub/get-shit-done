---
phase: 02-core-app
plan: 04
subsystem: ui
tags: [swiftui, swift-charts, stats, streak, tdd]
dependency_graph:
  requires: [02-core-app/02-01, 02-core-app/02-02, 02-core-app/02-03]
  provides: [StatsListView, HabitStatsView]
  affects: []
tech_stack:
  added: [Swift Charts (Charts framework)]
  patterns:
    - "StatsListView @Query pattern mirrors HistoryListView — sorted by sortOrder, ContentUnavailableView for empty state"
    - "HabitStatsView computes all stats inline from StatsCalculator pure functions — no @Query needed"
    - "30-day bar chart uses Charts BarMark with Color.appAccent for completed, Color(.systemGray4) for missed days"
    - "LazyVGrid with 3 equal columns for stat cards — RoundedRectangle secondarySystemBackground cards"
key_files:
  created:
    - HabitX/HabitX/Features/Stats/StatsListView.swift
    - HabitX/HabitX/Features/Stats/HabitStatsView.swift
  modified:
    - HabitX/HabitX/Features/Root/TabRootView.swift
    - HabitX.xcodeproj/project.pbxproj
decisions:
  - "Color.appAccent used directly — plan referenced HabitDefaults.appAccentColor but actual codebase uses Color extension static let appAccent (established in 02-01)"
  - "StatCard extracted as private struct within HabitStatsView — avoids naming collision, keeps component self-contained"
  - "BarMark x-axis labels every 7 days to avoid crowding on 30-day chart"
metrics:
  duration: ~10 min
  completed_date: "2026-03-30"
  tasks_completed: 2
  files_created: 2
  files_modified: 2
---

# Phase 02 Plan 04: Stats Tab Summary

**One-liner:** Swift Charts 30-day bar chart with streak + rate stat cards using StatsCalculator pure functions; neutral gray for missed days enforces STAT-04 positive-framing requirement.

## What Was Built

### StatsListView (HabitX/HabitX/Features/Stats/StatsListView.swift)

Stats tab root view. Uses `@Query(sort: \HabitSchemaV1.Habit.sortOrder)` to render all habits in a `List`. Each row shows the habit name and a quick streak preview ("Current streak: X days") computed inline via `StatsCalculator.currentStreak(for:)`. Tapping any row navigates to `HabitStatsView(habit:)` via `NavigationLink`. Empty state shows `ContentUnavailableView` with chart.bar icon, matching the pattern established by HistoryListView.

### HabitStatsView (HabitX/HabitX/Features/Stats/HabitStatsView.swift)

Per-habit detail view. Layout: ScrollView containing stat cards grid and 30-day chart.

**Stat Cards:** Three `StatCard` components in a `LazyVGrid` (3 equal flexible columns):
- Current Streak: `StatsCalculator.currentStreak(for:)` in days
- Best Streak: `StatsCalculator.bestStreak(for:)` in days
- 30-Day Rate: `Int(StatsCalculator.completionRate30Days(for:) * 100)%`

Each card uses `RoundedRectangle` with `Color(.secondarySystemBackground)` fill and `Color.appAccent` for the number value.

**30-Day Chart:** Swift Charts `BarMark` chart using `StatsCalculator.completionByDay(for:days:30)`. Completed days render with `Color.appAccent`; missed days render with `Color(.systemGray4)` — a neutral light gray. Y-axis is hidden (binary 0/1 values). X-axis shows abbreviated day labels every 7 days. Chart height: 200pt. Below the chart: "X of 30 days completed" caption in secondary text.

STAT-04 compliance: no red, orange, or warning colors used anywhere. No "missed" or "failed" labels. Missed days are simply shorter gray bars.

### TabRootView update (HabitX/HabitX/Features/Root/TabRootView.swift)

Replaced both placeholder Text views:
- History tab: `Text("History — Coming Soon")` → `HistoryListView()`
- Stats tab: `Text("Stats — Coming Soon")` → `StatsListView()`

All three tabs now render real views.

## Task Commits

1. **Task 1: StatsListView and HabitStatsView** — `d650075`
2. **Task 2: Wire HistoryListView and StatsListView into TabRootView** — `b92641c`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Color.appAccent vs HabitDefaults.appAccentColor**
- **Found during:** Task 1 (reviewing existing codebase before writing)
- **Issue:** Plan interfaces section referenced `HabitDefaults.appAccentColor`, but plan 02-01 implemented it as `Color.appAccent` (static extension on Color). HabitDefaults does not export an `appAccentColor` property.
- **Fix:** Used `Color.appAccent` consistently throughout both new files, matching the established pattern from HabitHistoryView and other existing views.
- **Files modified:** `HabitStatsView.swift` (written with correct API from the start)
- **Impact:** No behavior change — same color value, correct API.

None - plan executed cleanly with one minor API name correction.

## Verification

1. `xcodebuild build` BUILD SUCCEEDED for HabitX target (both tasks)
2. Stats tab shows habit list with current streak preview via StatsCalculator
3. Tapping a habit shows three stat cards (current streak, best streak, 30-day rate)
4. 30-day bar chart renders with accent color for completed days and Color(.systemGray4) for missed days
5. No red/warning/failure styling anywhere in the stats view (STAT-04 compliance)
6. Empty state shows ContentUnavailableView when no habits exist
7. StatsCalculator.currentStreak, .bestStreak, .completionRate30Days, .completionByDay all called correctly
8. Both History and Stats tabs render real views (no more placeholder text)

## Known Stubs

None - all views are fully wired to live SwiftData data via @Query and StatsCalculator.

## Self-Check: PASSED
