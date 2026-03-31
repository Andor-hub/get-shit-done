# Phase 3: Widgets - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Build WidgetKit home screen widgets for HabitX: a per-habit small widget (AppIntentConfiguration) and an all-habits overview medium widget (StaticConfiguration). Interactive AppIntents handle boolean toggle and count increment; input habits deep-link into the app. No in-app UI changes — widgets are additive on top of the Phase 2 main app.

</domain>

<decisions>
## Implementation Decisions

### Widget Visual Design

- **D-01:** Progress indicator style is a **circular progress ring with a fraction label in the center** (e.g. "3/8" for Water, "50/150g" for Protein). Habit name above, unit below.
- **D-02:** **Completed state**: ring fills fully in accent color, fraction is replaced by a **checkmark (✓)**, label below changes to "Done!". Visually distinct and satisfying.
- **D-03:** Incomplete state uses the existing app accent color for the filled portion of the ring; unfilled portion uses system gray.

### Small Widget (per-habit)

- **D-04:** Small widget uses **AppIntentConfiguration** — user picks which habit it shows via iOS widget edit mode (long-press widget → Edit Widget → select habit from dropdown).
- **D-05:** Layout: habit name at top, ring + fraction in center, unit label at bottom. Single tap on the widget triggers the interaction (toggle for boolean, +1 for count, deep-link for input).

### Medium Widget (all-habits overview)

- **D-06:** Medium widget is a **StaticConfiguration** (no user configuration needed) — it automatically shows **all habits** as a list of rows.
- **D-07:** Each row layout: `[habit name]  [mini ring]  [progress text]  [+]`. The ring is smaller than the small widget version; the progress text shows the fraction (e.g. "3/8 cups").
- **D-08:** Tapping `[+]` on a **boolean habit** toggles done/undone. Tapping `[+]` on a **count habit** increments by 1. Tapping `[+]` on an **input habit** opens the app to that habit's log entry sheet (same deep-link behavior as the small input widget).
- **D-09:** Completed habits in the overview still show a ✓ instead of the fraction. The `[+]` button remains visible (user can un-log a boolean by tapping it again; count habits can still be incremented beyond target).

### In-App Discovery

- **D-10:** **No in-app widget onboarding** — users add widgets through the standard iOS home screen flow (long-press → + → search HabitX). The app does not add any UI to guide widget discovery. Keep the app minimal.

### Widget Refresh

- **D-11 (Claude's discretion):** After any AppIntent action (toggle/increment/deep-link trigger), call `WidgetCenter.shared.reloadAllTimelines()` to refresh all widget instances. The main app also calls `reloadAllTimelines()` after any logging action, satisfying WID-05 (Today view reflects widget interactions without stale data).

### Deep-Link Protocol

- **D-12 (Claude's discretion):** Input habit widgets (small and medium) use an `OpenURLIntent` or a custom URL scheme (`habitx://log?id=<habitId>`) to open the app directly to the NumberInputSheet for that habit. Implementation approach is Claude's discretion.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — WID-01 through WID-05 are the widget requirements
- `.planning/ROADMAP.md` — Phase 3 success criteria (small + medium families, physical device verification, Today view reflects widget interactions)
- `.planning/PROJECT.md` — Core value: "one tap from home screen", iOS 17+ constraint

### Existing Code (Phase 1–2 output)
- `HabitX/HabitX/Models/Schema/HabitSchemaV1.swift` — `Habit` and `HabitLog` @Model definitions; `HabitType` enum (boolean/count/input). Widget reads these models.
- `HabitX/HabitX/Models/SharedModelContainer.swift` — Shared ModelContainer using App Group `group.com.habitx.shared`. Widget MUST use this same container.
- `HabitX/HabitXWidget/HabitXWidget.swift` — Existing placeholder widget (TimelineProvider, EntryView, Widget struct). Phase 3 replaces this placeholder with real implementation.
- `HabitX/HabitXWidget/HabitXWidgetBundle.swift` — WidgetBundle entry point. Will need updating if a second widget kind is added (small vs medium are families of the same widget kind, so bundle may stay as-is).
- `HabitX/HabitX/Services/HabitLogService.swift` — `toggleBoolean`, `incrementCount`, `setValue` methods. AppIntents in the widget extension must use compatible logic (cannot import the service directly — must duplicate or share via a target-agnostic utility).
- `HabitX/HabitX/Utilities/HabitDefaults.swift` — `Color.appAccent` extension. Widget views must reference the same accent color.

### Technology Constraints
- `CLAUDE.md` — iOS 17+ minimum; interactive widgets require `AppIntents` (not the old `SiriKit` intents); `AppIntentTimelineProvider` for widgets with configuration; `AppIntentConfiguration` for per-habit small widget.

</canonical_refs>

<code_context>
## Existing Code Insights

### Widget Target State
- `HabitXWidget.swift` is a placeholder — `HabitWidgetEntry` has only `date: Date`, no habit data. `HabitXWidgetEntryView` shows hardcoded "HabitX" text. Full replacement required.
- Widget already has `SharedModelContainer.container` wired as `.modelContainer()` in the widget config — the data access pattern is established.
- Widget supports `.systemSmall` and `.systemMedium` — matches the two-family requirement.
- No AppIntents exist anywhere in the project yet.

### Patterns from Phase 2
- `HabitLogService` is `@MainActor` and takes an explicit `ModelContext` — AppIntents must create their own `ModelContext` from `SharedModelContainer.container` in their `perform()` method.
- `HabitType` enum: `.boolean`, `.count`, `.input` — switch on this to dispatch the right AppIntent action.
- `Color.appAccent` is defined in `HabitDefaults.swift` — must be accessible from the widget extension target (add file to widget target or duplicate the extension).

### Integration Points
- Widget reading habits: `@Query` is not available in WidgetKit — must fetch using `ModelContext` in the `TimelineProvider.getTimeline()` method.
- Widget interactions → main app sync: `WidgetCenter.shared.reloadAllTimelines()` after any log action. Main app also calls this after logging so widget stays fresh (WID-05).

</code_context>

<specifics>
## Specific Ideas

- The medium overview widget is the power-user widget — a user with 3 habits can add one medium widget and log everything from the home screen without opening the app.
- Ring + checkmark completed state mirrors the app's HabitCardView completed styling (accent background tint + visual indicator), maintaining visual consistency between app and widget.
- The small widget per-habit picker in widget edit mode is the standard iOS pattern — no custom app UI needed to "assign" a habit to a widget.

</specifics>

<deferred>
## Deferred Ideas

- **Lock screen widgets** (WID-06 in v2 requirements) — out of scope for Phase 3.
- **Overview widget showing all habits at a glance as a large widget** — could be added in Phase 4 polish if time allows, but not in Phase 3 scope.

</deferred>

---

*Phase: 03-widgets*
*Context gathered: 2026-03-30*
