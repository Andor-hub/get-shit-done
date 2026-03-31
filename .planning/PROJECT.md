# HabitX 2.0

## What This Is

A native iOS habit tracking app built around a widget-first philosophy — users mark habits complete directly from their iPhone home screen without opening the app. HabitX 2.0 supports multiple habit types (boolean, count-based, numerical input), starts with Protein and Water as curated defaults, and shows daily progress, history, and stats in the main app.

## Core Value

Logging a habit is so frictionless — one tap from the home screen — that it becomes a reflex, not a chore.

## Requirements

### Validated

(None yet — ship to validate)

### Active

**Habit Management**
- [ ] User can add a custom habit with a name, type (boolean / count / input), and daily target
- [ ] User can choose from default habits (Protein, Water) with pre-suggested targets
- [ ] User can edit or delete any habit
- [ ] Habits have per-habit notification reminders at a user-set time

**Habit Types**
- [ ] Boolean habits: one tap marks done/undone
- [ ] Count habits: tap increments a counter toward a daily target (e.g. cups of water)
- [ ] Input habits: user enters a numerical value that accumulates toward a daily target (e.g. grams of protein)

**Widget Experience**
- [ ] Each habit has a dedicated iOS home screen widget
- [ ] Count habits (water): interactive widget — tap to increment
- [ ] Input habits (protein): widget shows today's total; tapping opens app to log a value
- [ ] Boolean habits: interactive widget — tap to toggle done/undone
- [ ] All widgets show progress toward daily target at a glance

**Main App**
- [ ] Today view: all habits listed with current progress and quick-log controls
- [ ] History view: per-habit log of past completions
- [ ] Stats view: completion rates, streaks, trends per habit

**Notifications**
- [ ] Per-habit push notifications at a user-configured time each day

**Storage**
- [ ] All data stored on-device (SwiftData) — no account or network required in v1

### Out of Scope

- Accounts / user profiles — deferred to v2 (social/friends features planned)
- Friends & social tracking — future milestone, requires backend
- Cloud sync — tied to accounts, out of v1
- Apple Health integration — out of v1, keep scope tight
- Android / cross-platform — native iOS only
- Habit categories / tags — keep UI simple for v1
- Gamification / badges — not in v1, focus on friction reduction

## Context

- Project name reflects a v1 already explored but not clean enough to extend — this is a fresh, intentional rewrite
- Future milestone: social features where friends can see each other's habit streaks — architecture should not block adding a backend/auth layer later
- Platform: iOS 17+ minimum to support interactive WidgetKit (AppIntents + interactive widgets require iOS 17)
- SwiftUI + WidgetKit + SwiftData is the natural stack for this target

## Constraints

- **Platform**: Native iOS (Swift/SwiftUI) only — user explicitly wants App Store distribution and best widget support
- **Widget interactivity**: iOS 17+ required for interactive widgets (buttons/toggles in WidgetKit via AppIntents)
- **Text input in widgets**: Not supported by iOS — input habits (protein) must open the app to log values
- **Storage**: On-device SwiftData for v1 — must be designed to migrate to CloudKit or custom backend later
- **Complexity**: Keep it as simple as possible — every feature decision should reduce friction, not add it

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Widget-first UX | Habit logging must be zero-friction; home screen widgets eliminate app-open friction | — Pending |
| SwiftData for persistence | Native Apple framework, easy CloudKit migration path for future social features | — Pending |
| iOS 17+ minimum | Required for interactive WidgetKit widgets (AppIntents API) | — Pending |
| On-device only in v1 | Simplicity first; social/cloud deferred to keep v1 shippable | — Pending |
| Three habit types (boolean / count / input) | Covers all use cases without over-engineering the model | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-27 after initialization*
