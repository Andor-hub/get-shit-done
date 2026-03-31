---
phase: 01-foundation
plan: 01
subsystem: infra
tags: [xcodegen, xcode, swiftui, widgetkit, swift6, app-groups, ios]

# Dependency graph
requires: []
provides:
  - Xcode project with HabitX app target (com.habitx.app) and HabitXWidget extension target (com.habitx.app.widget)
  - App Groups entitlement (group.com.habitx.shared) on both targets
  - Swift 6 strict concurrency enabled project-wide (SWIFT_STRICT_CONCURRENCY=complete)
  - iOS 17.0 minimum deployment target
  - WidgetKit extension scaffold with StaticConfiguration placeholder
  - Both targets build successfully with BUILD SUCCEEDED
affects: [01-02, phase-2, phase-3]

# Tech tracking
tech-stack:
  added: [xcodegen 2.45.3, WidgetKit, SwiftUI, Swift 6.0]
  patterns:
    - xcodegen project.yml as source of truth for Xcode project configuration
    - GENERATE_INFOPLIST_FILE=true for both targets (avoids manual Info.plist management)
    - Entitlements files as XML plists managed by xcodegen spec

key-files:
  created:
    - project.yml
    - HabitX.xcodeproj/project.pbxproj
    - HabitX/HabitX/HabitXApp.swift
    - HabitX/HabitX/ContentView.swift
    - HabitX/HabitX/HabitX.entitlements
    - HabitX/HabitXWidget/HabitXWidget.swift
    - HabitX/HabitXWidget/HabitXWidgetBundle.swift
    - HabitX/HabitXWidget/HabitXWidgetEntitlements.entitlements
  modified: []

key-decisions:
  - "GENERATE_INFOPLIST_FILE=true added to both targets — xcodegen does not set this by default; required for code signing without a hand-crafted Info.plist"
  - "group.com.habitx.shared as App Group identifier — matches INFRA-04 requirement; identical on both targets per entitlements files"
  - "xcodeVersion: 16.3 in project.yml — pinned to Xcode 16.3 per CLAUDE.md stack requirement (App Store requires Xcode 16+)"

patterns-established:
  - "xcodegen project.yml: regenerate Xcode project from project.yml when target membership or settings change — never edit project.pbxproj directly"
  - "Entitlements: both targets must declare group.com.habitx.shared under com.apple.security.application-groups; widget reads no data without this"

requirements-completed: [INFRA-04]

# Metrics
duration: 15min
completed: 2026-03-28
---

# Phase 01 Plan 01: Xcode Project Setup Summary

**xcodegen-generated Xcode project with HabitX app (com.habitx.app) and HabitXWidget extension (com.habitx.app.widget) targets, both configured with group.com.habitx.shared App Group and Swift 6 strict concurrency enabled**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-28T17:55:00Z
- **Completed:** 2026-03-28T18:10:00Z
- **Tasks:** 2
- **Files modified:** 9 created, 0 modified

## Accomplishments
- Created `project.yml` xcodegen spec with both HabitX and HabitXWidget targets
- Generated `HabitX.xcodeproj` via `xcodegen generate` with correct target configuration
- Both targets have App Groups entitlement with `group.com.habitx.shared`
- Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY=complete`) enabled project-wide
- HabitX app target BUILD SUCCEEDED on iOS Simulator (iPhone 17, iOS 26.3.1)
- HabitXWidget extension target BUILD SUCCEEDED independently
- Build settings verified: correct bundle IDs, entitlements paths, and concurrency settings

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Xcode project with xcodegen and both targets** - `70a78b7` (feat)
2. **Task 2: Verify widget extension target builds independently** - no file changes (verification only)

**Plan metadata:** (committed with SUMMARY.md below)

## Files Created/Modified
- `project.yml` - xcodegen spec defining both targets, App Groups, Swift 6 settings, bundle IDs
- `HabitX.xcodeproj/project.pbxproj` - generated Xcode project file
- `HabitX/HabitX/HabitXApp.swift` - Main app entry point with `@main` and `WindowGroup`
- `HabitX/HabitX/ContentView.swift` - Placeholder view showing "HabitX" text
- `HabitX/HabitX/HabitX.entitlements` - App Groups entitlement for main app target
- `HabitX/HabitXWidget/HabitXWidgetBundle.swift` - Widget bundle entry point (`@main`)
- `HabitX/HabitXWidget/HabitXWidget.swift` - Widget scaffold with StaticConfiguration placeholder
- `HabitX/HabitXWidget/HabitXWidgetEntitlements.entitlements` - App Groups entitlement for widget target

## Decisions Made
- Added `GENERATE_INFOPLIST_FILE: true` to both targets in `project.yml` — xcodegen does not set this flag by default, and without it xcodebuild fails code signing with "target does not have an Info.plist file". This is a necessary build setting for modern Xcode projects without manual Info.plist files.
- Chose `xcodeVersion: "16.3"` — pinned to Xcode 16.3 per CLAUDE.md stack requirement; App Store submissions require Xcode 16+.
- Verified build using `id=FED28E7E-AFA0-4F2D-AFA4-BF9101748F04` (iPhone 17 simulator) — the `iPhone 16` destination name in the plan does not exist in this Xcode installation (Xcode ships with iPhone 17 line simulators).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added GENERATE_INFOPLIST_FILE=true to both targets**
- **Found during:** Task 1 (first xcodebuild attempt)
- **Issue:** Plan's `project.yml` spec did not include `GENERATE_INFOPLIST_FILE: true`. Without it, xcodebuild fails: "Cannot code sign because the target does not have an Info.plist file and one is not being generated automatically."
- **Fix:** Added `GENERATE_INFOPLIST_FILE: true` to both `HabitX` and `HabitXWidget` target settings in `project.yml`, then re-ran `xcodegen generate`
- **Files modified:** `project.yml`
- **Verification:** `xcodebuild ... build` returned `BUILD SUCCEEDED` for both targets
- **Committed in:** `70a78b7` (Task 1 commit)

**2. [Rule 3 - Blocking] Used simulator UDID instead of name for -destination**
- **Found during:** Task 1 (second xcodebuild attempt)
- **Issue:** Plan's verify command uses `-destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'` but iPhone 16 does not exist in this Xcode installation. First attempt with `name=iPhone 17` returned "Supported platforms for the buildables in the current scheme is empty."
- **Fix:** Listed available simulators with `xcrun simctl list devices available`, used UDID `id=FED28E7E-AFA0-4F2D-AFA4-BF9101748F04` (iPhone 17) as the destination
- **Files modified:** None (command-line argument only)
- **Verification:** Both targets built with `BUILD SUCCEEDED`
- **Committed in:** `70a78b7` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug fix, 1 blocking)
**Impact on plan:** Both fixes necessary for build success. No scope creep. The `GENERATE_INFOPLIST_FILE` fix is required for all modern xcodegen projects — the plan spec was incomplete.

## Issues Encountered
- xcodegen entitlements block generates the `.entitlements` file content automatically, but the explicit `CODE_SIGN_ENTITLEMENTS` setting in the target settings is also needed for xcodebuild to locate it — both are present in the spec.

## Known Stubs
- `HabitX/HabitX/ContentView.swift` — shows `Text("HabitX")` placeholder; will be replaced in Phase 2 (Core App) with the Today view
- `HabitX/HabitXWidget/HabitXWidget.swift` — `HabitXWidgetEntryView` shows `Text("HabitX")` placeholder; will be replaced in Phase 3 (Widgets) with real habit data display
- `HabitTimelineProvider.getTimeline` — uses `.never` policy and returns a single static entry; intentional placeholder until Phase 3 adds SwiftData integration

These stubs are intentional and expected — Plan 01-01 only establishes the project skeleton. Plans 01-02 (SwiftData schema) and Phase 2/3 will wire real data.

## User Setup Required
None — no external service configuration required for this plan. App Groups configuration in the Apple Developer portal is required before TestFlight (noted as a blocker in STATE.md), but no action needed in local development.

## Next Phase Readiness
- Xcode project skeleton is complete and buildable — Plan 01-02 can proceed to add the SwiftData schema layer
- Both entitlements files have the correct App Group identifier — ready for `ModelConfiguration(groupContainer: .identifier("group.com.habitx.shared"))` in Plan 01-02
- Swift 6 strict concurrency is enabled — all new model code must be Swift 6 compliant from the start
- **Blocker (pre-TestFlight):** App Groups entitlement must be verified on a physical device in Release configuration — Simulator does not catch provisioning drift between Debug and Release profiles

---
*Phase: 01-foundation*
*Completed: 2026-03-28*

## Self-Check: PASSED

- FOUND: `project.yml`
- FOUND: `HabitX/HabitX/HabitXApp.swift`
- FOUND: `HabitX/HabitX/HabitX.entitlements`
- FOUND: `HabitX/HabitXWidget/HabitXWidgetEntitlements.entitlements`
- FOUND: `HabitX.xcodeproj`
- FOUND commit: `70a78b7` (feat(01-01): create Xcode project with two targets and App Groups)
