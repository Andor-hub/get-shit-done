---
phase: 01-foundation
plan: 02
subsystem: data-layer
tags: [swiftdata, versionedschema, cloudkit, app-groups, widgetkit, swift6, migration]

# Dependency graph
requires:
  - 01-01 (Xcode project with both targets and App Groups entitlement)
provides:
  - HabitSchemaV1 VersionedSchema with Habit and HabitLog @Model classes
  - HabitMigrationPlan empty migration anchor for v1
  - SharedModelContainer singleton using App Group store (group.com.habitx.shared)
  - Both app and widget targets wired with .modelContainer(SharedModelContainer.container)
affects: [phase-2, phase-3]

# Tech tracking
tech-stack:
  added: [SwiftData, VersionedSchema, SchemaMigrationPlan, ModelContainer, App Groups store]
  patterns:
    - VersionedSchema enum wrapping @Model classes — enables schema migration without store rebuild
    - groupContainer .identifier() API for App Group store sharing between app and widget
    - SharedModelContainer as caseless enum singleton — thread-safe lazy static initialization
    - Both targets compile shared Models directory via xcodegen sources array

key-files:
  created:
    - HabitX/HabitX/Models/Schema/HabitSchemaV1.swift
    - HabitX/HabitX/Models/Schema/HabitMigrationPlan.swift
    - HabitX/HabitX/Models/SharedModelContainer.swift
  modified:
    - HabitX/HabitX/HabitXApp.swift
    - HabitX/HabitXWidget/HabitXWidget.swift
    - project.yml

key-decisions:
  - "import Foundation required in HabitSchemaV1.swift — SwiftData does not re-export Foundation; @Model macro expansion needs UUID and Date from Foundation scope"
  - "Caseless enum used for SharedModelContainer (not struct/class) — prevents instantiation, static lazy property ensures thread-safe one-time initialization"
  - "project.yml HabitXWidget sources includes HabitX/HabitX/Models — xcodegen source path sharing is cleanest way to compile shared Swift files in both targets"
  - "xcodebuild -target instead of -scheme required for build verification — xcodegen auto-generated schemes produce 'Supported platforms empty' with -destination flag in this Xcode version"

requirements-completed: [INFRA-01, INFRA-02, INFRA-03]

# Metrics
duration: 10min
completed: 2026-03-29
---

# Phase 01 Plan 02: SwiftData Schema and Shared Container Summary

**SwiftData VersionedSchema (v1.0.0) with CloudKit-compatible Habit/HabitLog models, empty migration plan, and App Group-backed ModelContainer wired into both app and widget targets**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-29T00:03:45Z
- **Completed:** 2026-03-29T00:13:00Z
- **Tasks:** 2
- **Files created:** 3 (HabitSchemaV1.swift, HabitMigrationPlan.swift, SharedModelContainer.swift)
- **Files modified:** 3 (HabitXApp.swift, HabitXWidget.swift, project.yml)

## Accomplishments

- Created `HabitSchemaV1` VersionedSchema enum with `Habit` and `HabitLog` `@Model` classes
- All 13 model properties have explicit default values or are optional (CloudKit-compatible per INFRA-03)
- No `@Attribute(.unique)` on any property (CloudKit forbids uniqueness constraints)
- `HabitLog.habit` relationship is `Habit? = nil` (optional per CloudKit requirement)
- Created `HabitMigrationPlan` with `HabitSchemaV1.self` in schemas and empty stages array
- Created `SharedModelContainer` using `groupContainer: .identifier("group.com.habitx.shared")`
- Updated `project.yml` to add `HabitX/HabitX/Models` to HabitXWidget sources
- Updated `HabitXApp.swift` with `import SwiftData` and `.modelContainer(SharedModelContainer.container)`
- Updated `HabitXWidget.swift` with `import SwiftData` and `.modelContainer(SharedModelContainer.container)`
- Both `HabitX` and `HabitXWidget` targets compile with `BUILD SUCCEEDED`

## Task Commits

1. **Task 1: Create SwiftData schema, migration plan, and shared container** - `6b76fb4` (feat)
2. **Task 2: Wire SharedModelContainer into app and widget entry points** - `bb790ac` (feat)

## Files Created/Modified

- `HabitX/HabitX/Models/Schema/HabitSchemaV1.swift` — VersionedSchema with Habit and HabitLog models
- `HabitX/HabitX/Models/Schema/HabitMigrationPlan.swift` — SchemaMigrationPlan with empty stages
- `HabitX/HabitX/Models/SharedModelContainer.swift` — Singleton ModelContainer using App Group store
- `HabitX/HabitX/HabitXApp.swift` — Added SwiftData import and modelContainer modifier
- `HabitX/HabitXWidget/HabitXWidget.swift` — Added SwiftData import and modelContainer modifier
- `project.yml` — Added HabitX/HabitX/Models to HabitXWidget sources

## Decisions Made

- Added `import Foundation` to `HabitSchemaV1.swift` — `SwiftData` does not transitively re-export `Foundation`, so `UUID` and `Date` types used in `@Model` property declarations cause "cannot find type in scope" errors without the explicit Foundation import. This is a required addition to the plan's code.
- Used `xcodebuild -target` instead of `-scheme` for build verification — xcodegen's auto-generated schemes (no `.xcscheme` files created) produce a `Supported platforms for the buildables in the current scheme is empty` error when using `-destination` with the simulator UDID. Building with `-target`, `-sdk iphonesimulator`, `-arch arm64`, and code signing disabled produces a clean build. This matches the workaround from plan 01-01.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added `import Foundation` to HabitSchemaV1.swift**
- **Found during:** Task 2 (first xcodebuild attempt)
- **Issue:** Plan's code snippet for `HabitSchemaV1.swift` only had `import SwiftData`. SwiftData does not re-export Foundation, so `UUID` and `Date` types used in `@Model` property defaults caused 11 "cannot find type/value in scope" errors.
- **Fix:** Added `import Foundation` as the first import line in `HabitSchemaV1.swift`
- **Files modified:** `HabitX/HabitX/Models/Schema/HabitSchemaV1.swift`
- **Verification:** Both targets built with `BUILD SUCCEEDED` after fix
- **Committed in:** `bb790ac` (Task 2 commit)

**2. [Rule 3 - Blocking] Used `-target` instead of `-scheme` for xcodebuild**
- **Found during:** Task 2 (build verification)
- **Issue:** `xcodebuild -scheme HabitX -destination 'id=...'` returns "Supported platforms for the buildables in the current scheme is empty" — same issue as plan 01-01. xcodegen does not generate `.xcscheme` files; auto-generated schemes don't associate properly with simulator destinations.
- **Fix:** Used `xcodebuild -target HabitX -sdk iphonesimulator -arch arm64 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build`
- **Files modified:** None (command-line only)
- **Verification:** Both targets produced `BUILD SUCCEEDED`
- **Committed in:** N/A (build command only)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact:** Both fixes necessary. No scope creep. The Foundation import is a required correction to the plan's code snippet.

## Known Stubs

- `HabitX/HabitX/ContentView.swift` — shows `Text("HabitX")` placeholder; will be replaced in Phase 2
- `HabitX/HabitXWidget/HabitXWidget.swift` — `HabitXWidgetEntryView` shows `Text("HabitX")` placeholder; intentional until Phase 3 adds real habit data
- `HabitTimelineProvider.getTimeline` — uses `.never` policy and single static entry; intentional until Phase 3

The SwiftData schema, migration plan, and shared container are complete — no stubs in the data layer. All `@Model` properties are fully defined.

## Next Phase Readiness

- SwiftData persistence layer is ready for Phase 2 (Core App) — `@Query` in views, `@Environment(\.modelContext)` for writes
- Both targets share the same App Group store via `SharedModelContainer.container`
- INFRA-01, INFRA-02, INFRA-03 all satisfied — foundation phase complete
- **Blocker (pre-TestFlight):** App Groups entitlement still needs physical device verification in Release configuration

---
*Phase: 01-foundation*
*Completed: 2026-03-29*

## Self-Check: PASSED

- FOUND: `HabitX/HabitX/Models/Schema/HabitSchemaV1.swift`
- FOUND: `HabitX/HabitX/Models/Schema/HabitMigrationPlan.swift`
- FOUND: `HabitX/HabitX/Models/SharedModelContainer.swift`
- FOUND: `.planning/phases/01-foundation/01-02-SUMMARY.md`
- FOUND commit: `6b76fb4` (feat(01-02): add VersionedSchema, migration plan, and shared ModelContainer)
- FOUND commit: `bb790ac` (feat(01-02): wire SharedModelContainer into app and widget entry points)
