# Roadmap: HabitX 2.0

## Overview

HabitX 2.0 ships as a native iOS habit tracker where every interaction is designed for minimum friction. The build order is architecturally constrained: infrastructure (App Groups, VersionedSchema, shared data layer) must exist before any feature can be built on top of it; the main app must be working before the widget extension reads from it; and notifications can only be layered on once the core loop is solid. Four phases follow this order precisely — Foundation, Core App, Widgets, and Notifications + Polish — each delivering a verifiable, self-contained capability.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Xcode project, shared data layer, App Groups, VersionedSchema — everything the app and widget depend on (completed 2026-03-29)
- [ ] **Phase 2: Core App** - Today view, habit management, all three logging types, History, and Stats
- [ ] **Phase 3: Widgets** - Per-habit home screen widgets with read display and interactive tap-to-log
- [ ] **Phase 4: Notifications + Polish** - Per-habit daily reminders, notification permission flow, and App Store pre-submission tasks

## Phase Details

### Phase 1: Foundation
**Goal**: The project infrastructure is correct and shared — both targets use the same App Group store, the data schema is versioned from day one, and all model fields are CloudKit-compatible before a single feature is built
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04
**Success Criteria** (what must be TRUE):
  1. The main app and widget extension targets both read and write from the same SwiftData store in the shared App Group container (verified on a physical device, not just Simulator)
  2. SwiftData models are defined under a VersionedSchema (`HabitSchemaV1`) with a SchemaMigrationPlan — a TestFlight build can launch without crashing after any future schema change
  3. All `@Model` attributes have explicit defaults or are optional — CloudKit can be activated in v2 without a breaking migration
  4. The App Group container identifier matches on both targets in both Debug and Release provisioning profiles
**Plans:** 2/2 plans complete

Plans:
- [x] 01-01-PLAN.md — Xcode project creation with two targets, App Groups, entitlements, Swift 6
- [x] 01-02-PLAN.md — SwiftData schema (VersionedSchema), migration plan, shared ModelContainer

### Phase 2: Core App
**Goal**: Users can manage habits and log their daily progress from the main app — all three habit types work end-to-end with today's state, historical records, and stats visible
**Depends on**: Phase 1
**Requirements**: HAB-01, HAB-02, HAB-03, HAB-04, HAB-05, LOG-01, LOG-02, LOG-03, LOG-04, TODAY-01, TODAY-02, TODAY-03, TODAY-04, HIST-01, HIST-02, HIST-03, STAT-01, STAT-02, STAT-03, STAT-04
**Success Criteria** (what must be TRUE):
  1. User can create, edit, delete, and reorder habits including Protein and Water defaults with pre-filled targets; all changes persist across app restarts
  2. User can log any habit type (boolean tap, count increment, input value) from the Today view and see current progress vs. daily target with completed habits visually distinct
  3. All habit logs reset at midnight timezone-correctly — a habit completed on Monday shows as incomplete on Tuesday
  4. User can view a scrollable per-habit history going back at least 90 days showing logged values for each past day
  5. User can view streak (current and best), 30-day completion rate, and missed days displayed as neutral data (not penalized visually) for each habit
**Plans**: TBD
**UI hint**: yes

### Phase 3: Widgets
**Goal**: Every habit has a home screen widget that shows current progress and — for boolean and count habits — lets users log directly from the widget without opening the app
**Depends on**: Phase 2
**Requirements**: WID-01, WID-02, WID-03, WID-04, WID-05
**Success Criteria** (what must be TRUE):
  1. Each habit can be assigned to a home screen widget (small and medium families) showing today's progress toward its daily target at a glance
  2. Tapping a boolean habit widget toggles it done/undone and the widget updates immediately without opening the app (verified on physical device)
  3. Tapping a count habit widget (e.g. Water) increments the count by 1 and the widget updates immediately without opening the app (verified on physical device)
  4. Tapping an input habit widget (e.g. Protein) opens the app to the log entry sheet for manual value entry
  5. The Today view in the main app reflects widget interactions without showing stale data after returning to the foreground
**Plans**: TBD
**UI hint**: yes

### Phase 4: Notifications + Polish
**Goal**: Users receive a daily reminder for each habit they care about, the app is ready for App Store submission, and all three habit types have been regression-tested end-to-end on a physical device
**Depends on**: Phase 3
**Requirements**: NOTF-01, NOTF-02, NOTF-03, NOTF-04
**Success Criteria** (what must be TRUE):
  1. User can set a per-habit daily reminder time and receive a push notification at that time showing only the habit name (no coaching language)
  2. If the habit is already completed when the scheduled notification fires, the notification is cancelled automatically and does not appear
  3. The app requests notification permission only after the user sets a reminder time on their first habit — not on first launch
  4. The app passes App Store review with a valid PrivacyInfo.xcprivacy manifest on both targets and no crashes on final TestFlight regression
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 2/2 | Complete   | 2026-03-29 |
| 2. Core App | 0/TBD | Not started | - |
| 3. Widgets | 0/TBD | Not started | - |
| 4. Notifications + Polish | 0/TBD | Not started | - |
