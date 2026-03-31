---
phase: 04-notifications-polish
plan: 02
subsystem: app-store-readiness
tags: [privacy-manifest, xcprivacy, empty-states, regression-testing, testflight]
dependency_graph:
  requires: [04-01]
  provides: [PrivacyInfo.xcprivacy for both targets, TestFlight regression checklist]
  affects: [HabitX app target, HabitXWidget extension target, project.yml]
tech_stack:
  added: []
  patterns: [PrivacyInfo.xcprivacy per-bundle-target, XcodeGen fileTypes override for xcprivacy]
key_files:
  created:
    - HabitX/HabitX/PrivacyInfo.xcprivacy
    - HabitX/HabitXWidget/PrivacyInfo.xcprivacy
    - .planning/phases/04-notifications-polish/04-REGRESSION.md
  modified:
    - project.yml
    - HabitX/HabitX/Features/Today/TodayView.swift
decisions:
  - "Each target requires a separate physical PrivacyInfo.xcprivacy file — sharing one path causes XcodeGen Multiple commands produce build error"
  - "fileTypes xcprivacy buildPhase: resources override required in project.yml to ensure correct Copy Bundle Resources placement"
  - "TodayView empty state updated to include action hint; History and Stats views already action-oriented"
metrics:
  duration_minutes: 15
  completed_date: "2026-03-31"
  tasks_completed: 2
  files_changed: 5
---

# Phase 04 Plan 02: App Store Readiness (Privacy Manifests + Polish) Summary

**One-liner:** PrivacyInfo.xcprivacy for both HabitX and HabitXWidget targets with fileTypes XcodeGen override, action-oriented TodayView empty state copy, and 21-item physical-device TestFlight regression checklist.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create PrivacyInfo.xcprivacy for both targets and configure project.yml | 395d579 | HabitX/HabitX/PrivacyInfo.xcprivacy, HabitX/HabitXWidget/PrivacyInfo.xcprivacy, project.yml, HabitX.xcodeproj/project.pbxproj |
| 2 | Verify empty state copy and create regression checklist | 0b39e09 | HabitX/HabitX/Features/Today/TodayView.swift, .planning/phases/04-notifications-polish/04-REGRESSION.md |

## What Was Built

### PrivacyInfo.xcprivacy (Both Targets)

Created two separate `PrivacyInfo.xcprivacy` files — one per target directory:

- `HabitX/HabitX/PrivacyInfo.xcprivacy` — app target manifest
- `HabitX/HabitXWidget/PrivacyInfo.xcprivacy` — widget extension manifest

Both files declare:
- `NSPrivacyTracking: false` — no tracking
- `NSPrivacyTrackingDomains: []` — no tracking domains
- `NSPrivacyCollectedDataTypes: []` — no collected data types
- `NSPrivacyAccessedAPITypes: []` — no accessed API reasons

### project.yml fileTypes Override

Added `fileTypes: xcprivacy: buildPhase: resources` to the `options:` block. This ensures XcodeGen correctly places `.xcprivacy` files in Copy Bundle Resources rather than Compile Sources, satisfying App Store Connect's privacy manifest requirements.

### TodayView Empty State

Updated `emptyStateView` text from `"No habits yet"` to `"No habits yet -- tap + to add your first one"`. This provides the action hint specified in D-12. History and Stats views already had action-oriented copy directing users to the Today tab; those were left unchanged.

### 04-REGRESSION.md

Created a 21-item physical-device TestFlight regression checklist organized into three sections:

1. **Phase 3 Deferred Tests (5 items)** — Widget interactivity tests that cannot be verified in Simulator
2. **Phase 4 Notification Tests (7 items)** — Permission flows, scheduling, cancellation on completion
3. **General Regression (9 items)** — Habit creation, all three types, History/Stats/empty states

## Decisions Made

1. **Separate PrivacyInfo.xcprivacy files per target** — Sharing a single file path across both targets in XcodeGen produces a "Multiple commands produce" build error. Each target needs its own physical file in its own source directory.

2. **fileTypes override pre-emptively added** — Rather than waiting to see if XcodeGen places `.xcprivacy` in the correct build phase, the override was added proactively per RESEARCH Pitfall 5. This is a no-cost safety measure.

3. **TodayView copy updated, History/Stats unchanged** — The existing `HistoryListView` and `StatsListView` copy ("Add habits from the Today tab to see history/stats here.") already satisfies D-12's intent by directing users to the Today tab. Only TodayView's copy lacked the action hint.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all files created are complete and functional.

## Self-Check: PASSED

- HabitX/HabitX/PrivacyInfo.xcprivacy: FOUND
- HabitX/HabitXWidget/PrivacyInfo.xcprivacy: FOUND
- .planning/phases/04-notifications-polish/04-REGRESSION.md: FOUND (21 checkboxes)
- project.yml fileTypes xcprivacy override: FOUND
- TodayView action hint copy: FOUND
- xcodebuild BUILD SUCCEEDED: VERIFIED
- Commits 395d579 and 0b39e09: FOUND
