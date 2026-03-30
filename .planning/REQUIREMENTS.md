# Requirements: HabitX 2.0

**Defined:** 2026-03-27
**Core Value:** Logging a habit is so frictionless — one tap from the home screen — that it becomes a reflex, not a chore.

## v1 Requirements

### Habit Management

- [ ] **HAB-01**: User can create a habit with a name, type (boolean / count / input), and daily target
- [x] **HAB-02**: User can choose from default habits (Protein, Water) with pre-filled recommended targets during onboarding
- [ ] **HAB-03**: User can edit a habit's name, type, target, and notification time
- [ ] **HAB-04**: User can delete a habit (with confirmation)
- [ ] **HAB-05**: User can reorder habits in the Today view

### Habit Logging

- [x] **LOG-01**: User can mark a boolean habit as done or undone from the Today view
- [x] **LOG-02**: User can increment a count habit (e.g. +1 cup of water) from the Today view
- [x] **LOG-03**: User can log a numerical value for an input habit (e.g. 35g protein) from the Today view
- [x] **LOG-04**: All habit logs reset at midnight for the new day (timezone-aware)

### Widgets

- [ ] **WID-01**: Each habit has a configurable home screen widget that shows today's progress toward its daily target
- [ ] **WID-02**: Boolean habit widget: tap to toggle done/undone (interactive)
- [ ] **WID-03**: Count habit widget (water): tap to increment by 1 (interactive)
- [ ] **WID-04**: Input habit widget (protein): tapping opens the app to the log entry sheet
- [ ] **WID-05**: All widgets update immediately after interaction

### Today View

- [ ] **TODAY-01**: User sees all their habits in a single scrollable Today view
- [ ] **TODAY-02**: Each habit shows current progress vs. daily target
- [ ] **TODAY-03**: Completed habits are visually distinct from incomplete habits
- [ ] **TODAY-04**: User can log any habit type directly from the Today view

### History

- [x] **HIST-01**: User can view a per-habit log of past completions by date
- [x] **HIST-02**: History shows the logged value/count/completion for each past day
- [x] **HIST-03**: User can navigate back at least 90 days of history

### Stats

- [x] **STAT-01**: Each habit shows a current streak (consecutive days completed)
- [x] **STAT-02**: Each habit shows a best-ever streak
- [x] **STAT-03**: Each habit shows a 30-day completion rate (percentage)
- [ ] **STAT-04**: Missed days are displayed as neutral data (not punished visually)

### Notifications

- [ ] **NOTF-01**: User can set a per-habit daily reminder time
- [ ] **NOTF-02**: Notification copy shows only the habit name (no coaching language)
- [ ] **NOTF-03**: Notifications cancel automatically if the habit is already completed for the day
- [ ] **NOTF-04**: App requests notification permission at a contextually appropriate moment (not on first launch)

### Infrastructure

- [x] **INFRA-01**: All data stored on-device using SwiftData with App Groups for widget access
- [x] **INFRA-02**: SwiftData schema uses VersionedSchema from initial build (migration-safe for future updates)
- [x] **INFRA-03**: All SwiftData model attributes are optional or have defaults (CloudKit-compatible for future v2)
- [x] **INFRA-04**: App and widget extension share the same App Group container identifier

## v2 Requirements

### Social

- **SOCL-01**: User can create an account with email/password
- **SOCL-02**: User can add friends and view their habit streaks
- **SOCL-03**: User can see a friends activity feed (completions, streaks)
- **SOCL-04**: Data syncs to cloud when account exists

### Extended Widgets

- **WID-06**: Lock screen widgets per habit
- **WID-07**: Overview widget showing all habits at a glance

### Advanced Tracking

- **ADV-01**: Weekly/custom frequency habits (e.g. 3x per week, weekdays only)
- **ADV-02**: Apple Health integration for auto-import of steps, sleep, water
- **ADV-03**: Apple Watch complication

## Out of Scope

| Feature | Reason |
|---------|--------|
| Gamification / badges | Adds complexity without friction reduction — v1 focuses on logging simplicity |
| Apple Watch app | Widget-first approach covers the low-friction need; watch adds scope |
| Habit categories / tags | Not needed for v1 with a small habit list |
| In-app purchases / paywall | Monetization model to be decided; not in v1 scope |
| Apple Health auto-import | Auto-import reduces the intentional logging act; may conflict with core value |
| Android / cross-platform | Native iOS only |
| Motivational push copy | Users disable notifications with coaching language — habit name only |
| Hard habit limit | Recommend 3-6 habits in onboarding copy, but do not enforce a cap |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Complete |
| INFRA-02 | Phase 1 | Complete |
| INFRA-03 | Phase 1 | Complete |
| INFRA-04 | Phase 1 | Complete |
| HAB-01 | Phase 2 | Pending |
| HAB-02 | Phase 2 | Complete |
| HAB-03 | Phase 2 | Pending |
| HAB-04 | Phase 2 | Pending |
| HAB-05 | Phase 2 | Pending |
| LOG-01 | Phase 2 | Complete |
| LOG-02 | Phase 2 | Complete |
| LOG-03 | Phase 2 | Complete |
| LOG-04 | Phase 2 | Complete |
| TODAY-01 | Phase 2 | Pending |
| TODAY-02 | Phase 2 | Pending |
| TODAY-03 | Phase 2 | Pending |
| TODAY-04 | Phase 2 | Pending |
| HIST-01 | Phase 2 | Complete |
| HIST-02 | Phase 2 | Complete |
| HIST-03 | Phase 2 | Complete |
| STAT-01 | Phase 2 | Complete |
| STAT-02 | Phase 2 | Complete |
| STAT-03 | Phase 2 | Complete |
| STAT-04 | Phase 2 | Pending |
| WID-01 | Phase 3 | Pending |
| WID-02 | Phase 3 | Pending |
| WID-03 | Phase 3 | Pending |
| WID-04 | Phase 3 | Pending |
| WID-05 | Phase 3 | Pending |
| NOTF-01 | Phase 4 | Pending |
| NOTF-02 | Phase 4 | Pending |
| NOTF-03 | Phase 4 | Pending |
| NOTF-04 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 33 total
- Mapped to phases: 33
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-03-27 — traceability corrected: HIST and STAT moved to Phase 2 (Core App), matching ROADMAP.md*
