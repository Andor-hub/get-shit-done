---
phase: 03-widgets
plan: "01"
subsystem: widget-intents
tags: [appintents, widgetkit, swiftdata, swift6, appentity]
dependency_graph:
  requires:
    - 01-foundation/01-02 (SharedModelContainer)
    - 02-core-app/02-01 (HabitLogService, HabitDefaults)
  provides:
    - HabitEntity (AppEntity wrapper for widget picker)
    - HabitEntityQuery (entity query for picker)
    - HabitWidgetIntent (WidgetConfigurationIntent)
    - ToggleBooleanHabitIntent (AppIntent for toggle)
    - IncrementCountHabitIntent (AppIntent for increment)
    - HabitSnapshot (Sendable value type for timeline entries)
    - HabitWidgetEntry / MediumWidgetEntry (TimelineEntry types)
  affects:
    - 03-02 (widget views reference these types)
    - 03-03 (timeline provider references these types)
tech_stack:
  added:
    - AppIntents (HabitEntity, HabitEntityQuery, WidgetConfigurationIntent, AppIntent)
    - WidgetKit (TimelineEntry types)
  patterns:
    - AppIntent.perform() creates ModelContext(SharedModelContainer.container), saves explicitly, calls reloadAllTimelines()
    - static var -> static let for LocalizedStringResource properties to satisfy Swift 6 strict concurrency
    - HabitSnapshot inlines todayValue/isCompleted logic (no dependency on HabitLogService in widget target for Task 1)
key_files:
  created:
    - HabitX/HabitXWidget/Intents/HabitEntity.swift
    - HabitX/HabitXWidget/Intents/HabitEntityQuery.swift
    - HabitX/HabitXWidget/Intents/HabitWidgetIntent.swift
    - HabitX/HabitXWidget/Intents/ToggleBooleanHabitIntent.swift
    - HabitX/HabitXWidget/Intents/IncrementCountHabitIntent.swift
    - HabitX/HabitXWidget/Models/HabitSnapshot.swift
    - HabitX/HabitXWidget/Models/HabitWidgetEntry.swift
  modified:
    - HabitX/HabitXWidget/HabitXWidget.swift (updated to use HabitWidgetEntry from Models/)
    - project.yml (URL scheme + Utilities/Services sources for widget target)
    - HabitX.xcodeproj/project.pbxproj (regenerated via xcodegen)
decisions:
  - "static var -> static let for LocalizedStringResource and EntityQuery properties — Swift 6 strict concurrency requires immutable shared global state"
  - "HabitSnapshot inlines todayValue/isCompleted logic rather than calling HabitLogService — avoids Services source path being required for Task 1 build (added in Task 2)"
  - "URL scheme uses INFOPLIST_KEY_CFBundleURLTypes with old-style plist notation — required pattern for GENERATE_INFOPLIST_FILE=true in xcodegen"
  - "Build verification uses /tmp/HabitX-build derivedDataPath — avoids iCloud Drive xattr (resource fork) code-signing failures when building in iCloud-synced directory"
metrics:
  duration: "12 minutes"
  completed_date: "2026-03-30"
  tasks_completed: 2
  files_created: 7
  files_modified: 3
---

# Phase 03 Plan 01: AppIntent Infrastructure and Shared Widget Types Summary

AppIntents, EntityQuery, WidgetConfigurationIntent, two interactive AppIntents, and Sendable snapshot types created for the HabitXWidget target; habitx:// URL scheme registered; widget target gains access to Utilities and Services source paths.

## What Was Built

### Task 1: Create AppIntent infrastructure and shared widget types

Created 7 new Swift files in `HabitX/HabitXWidget/`:

**Intents/**
- `HabitEntity.swift` — `struct HabitEntity: AppEntity` with UUID id, name, habitType, unit fields. Powers the small widget's edit-mode picker dropdown via `HabitEntityQuery`.
- `HabitEntityQuery.swift` — `struct HabitEntityQuery: EntityQuery` with `@MainActor suggestedEntities()` and `@MainActor entities(for:)` fetching from `SharedModelContainer.container.mainContext`.
- `HabitWidgetIntent.swift` — `struct HabitWidgetIntent: WidgetConfigurationIntent` with `@Parameter var habit: HabitEntity?` for the small widget's configuration.
- `ToggleBooleanHabitIntent.swift` — `struct ToggleBooleanHabitIntent: AppIntent` with `@MainActor perform()` that creates a `ModelContext`, fetches the habit, toggles today's log, calls `context.save()`, then `WidgetCenter.shared.reloadAllTimelines()`.
- `IncrementCountHabitIntent.swift` — `struct IncrementCountHabitIntent: AppIntent` with same pattern: fetch, increment/create today's log, `context.save()`, `reloadAllTimelines()`.

**Models/**
- `HabitSnapshot.swift` — `struct HabitSnapshot: Sendable` capturing id, name, habitType, unit, dailyTarget, todayValue, isCompleted. Safe to cross actor boundaries into timeline entry storage.
- `HabitWidgetEntry.swift` — `struct HabitWidgetEntry: TimelineEntry` with `habitSnapshot: HabitSnapshot?` and `struct MediumWidgetEntry: TimelineEntry` with `snapshots: [HabitSnapshot]`.

Updated `HabitXWidget.swift` to remove the duplicate `HabitWidgetEntry` definition (moved to Models/) and reference the new version with `habitSnapshot` parameter.

### Task 2: Register habitx:// URL scheme and add Utilities/Services to widget target

Updated `project.yml`:
- Added `INFOPLIST_KEY_CFBundleURLTypes` to the HabitX app target with `CFBundleURLSchemes = (habitx)` for deep-link routing from widgets per D-12.
- Added `HabitX/HabitX/Utilities` and `HabitX/HabitX/Services` to HabitXWidget sources, giving the widget access to `Color.appAccent` and `HabitLogService`.

Regenerated `HabitX.xcodeproj` via `xcodegen generate`. Both HabitX and HabitXWidget targets build cleanly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 strict concurrency: static var -> static let for AppIntent properties**
- **Found during:** Task 1 build verification
- **Issue:** `static var title: LocalizedStringResource` and `static var description: IntentDescription` and `static var defaultQuery` trigger "nonisolated global shared mutable state" errors under `SWIFT_STRICT_CONCURRENCY: complete`. The plan specified `static var` in the action description but the fix is `static let` (immutable constants).
- **Fix:** Changed `static var` to `static let` in HabitWidgetIntent, ToggleBooleanHabitIntent, IncrementCountHabitIntent, and HabitEntity for all static constant properties.
- **Files modified:** All 4 Intents files
- **Commit:** 0129793

**2. [Rule 3 - Blocking] HabitSnapshot inlined todayValue/isCompleted logic to allow Task 1 build**
- **Found during:** Task 1 build verification
- **Issue:** `HabitSnapshot.swift` referenced `HabitLogService` which lives in `HabitX/HabitX/Services`. That path was not yet added to widget sources (Task 2's job). The plan's task ordering caused Task 1 to fail its own build check.
- **Fix:** Inlined the `todayValue`/`isCompleted` date-range filter logic directly in `HabitSnapshot.init`. Logic is identical to `HabitLogService`'s methods. Once Services is included (Task 2), the widget target has access to HabitLogService for future use by timeline providers.
- **Files modified:** HabitX/HabitXWidget/Models/HabitSnapshot.swift
- **Commit:** 0129793

**3. [Rule 3 - Blocking] Build verification used /tmp derivedDataPath to avoid iCloud Drive xattr failures**
- **Found during:** Task 1 and Task 2 build verification
- **Issue:** Building with `-target` flag while output lands in the iCloud-synced project directory causes macOS to add extended attributes to compiled `.app` bundles during the build, triggering `codesign` failure: "resource fork, Finder information, or similar detritus not allowed".
- **Fix:** Used `-scheme HabitXWidget -derivedDataPath /tmp/HabitX-build` to route all build artifacts outside iCloud. This is the correct approach for any CI-style build in an iCloud-synced workspace.
- **Files modified:** None (build invocation only)

## Known Stubs

- `HabitXWidget.swift` still uses a placeholder `HabitTimelineProvider` returning empty entries with `habitSnapshot: nil`. This is intentional — timeline provider implementation is 03-03's responsibility.
- `HabitXWidgetEntryView` renders `Text("HabitX")` — widget views are 03-02's responsibility.

These stubs do not prevent the plan's goal (AppIntent infrastructure) from being achieved. They will be resolved in 03-02 and 03-03.

## Self-Check: PASSED

Files exist:
- FOUND: HabitX/HabitXWidget/Intents/HabitEntity.swift
- FOUND: HabitX/HabitXWidget/Intents/HabitEntityQuery.swift
- FOUND: HabitX/HabitXWidget/Intents/HabitWidgetIntent.swift
- FOUND: HabitX/HabitXWidget/Intents/ToggleBooleanHabitIntent.swift
- FOUND: HabitX/HabitXWidget/Intents/IncrementCountHabitIntent.swift
- FOUND: HabitX/HabitXWidget/Models/HabitSnapshot.swift
- FOUND: HabitX/HabitXWidget/Models/HabitWidgetEntry.swift

Commits exist:
- 0129793: feat(03-01): add AppIntent infrastructure and shared widget types
- 93f3d57: feat(03-01): register habitx:// URL scheme and add Utilities/Services to widget target

Build verification:
- HabitXWidget: BUILD SUCCEEDED
- HabitX: BUILD SUCCEEDED
