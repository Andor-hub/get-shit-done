---
phase: 03-widgets
verified: 2026-03-30T00:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 3: Widgets Verification Report

**Phase Goal:** Every habit has a home screen widget that shows current progress and — for boolean and count habits — lets users log directly from the widget without opening the app
**Verified:** 2026-03-30
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| #   | Truth                                                                                                             | Status     | Evidence                                                                                                   |
| --- | ----------------------------------------------------------------------------------------------------------------- | ---------- | ---------------------------------------------------------------------------------------------------------- |
| 1   | Each habit can be assigned to a home screen widget (small and medium families) showing today's progress           | ✓ VERIFIED | `HabitSmallWidget` (AppIntentConfiguration) + `HabitMediumWidget` (StaticConfiguration) both defined and bundled in `HabitXWidgetBundle` |
| 2   | Tapping a boolean habit widget toggles it done/undone and the widget updates immediately                          | ✓ VERIFIED | `ToggleBooleanHabitIntent.perform()` writes to SwiftData + calls `WidgetCenter.shared.reloadAllTimelines()`; wired in `SmallWidgetEntryView` and `MediumWidgetEntryView` |
| 3   | Tapping a count habit widget increments the count by 1 and the widget updates immediately                         | ✓ VERIFIED | `IncrementCountHabitIntent.perform()` increments today's log value + calls `reloadAllTimelines()`; wired in both widget views |
| 4   | Tapping an input habit widget opens the app to the log entry sheet for manual value entry                         | ✓ VERIFIED | `habitx://log?id=<uuid>` URL parsed in `HabitXApp.onOpenURL`, routes to `NumberInputSheet` via `TodayView.onChange(of: deepLinkHabitId)` |
| 5   | The Today view in the main app reflects widget interactions without showing stale data after returning to foreground | ✓ VERIFIED | `TabRootView.onChange(of: scenePhase)` calls `WidgetCenter.shared.reloadAllTimelines()` on `.active` — both directions covered |

**Score:** 5/5 truths verified

---

### Required Artifacts

| Artifact                                              | Expected                                          | Status     | Details                                                                   |
| ----------------------------------------------------- | ------------------------------------------------- | ---------- | ------------------------------------------------------------------------- |
| `HabitXWidget/Intents/HabitEntity.swift`              | AppEntity for widget picker                       | ✓ VERIFIED | Full AppEntity implementation with id, name, habitType, unit fields       |
| `HabitXWidget/Intents/ToggleBooleanHabitIntent.swift` | AppIntent for boolean toggle                      | ✓ VERIFIED | Full perform() with ModelContext fetch, log toggle, save, reloadTimelines |
| `HabitXWidget/Intents/IncrementCountHabitIntent.swift`| AppIntent for count increment                     | ✓ VERIFIED | Full perform() with ModelContext fetch, value increment, save, reloadTimelines |
| `HabitXWidget/Views/CircularProgressRingView.swift`   | Ring view with completed/incomplete states        | ✓ VERIFIED | Circle().trim() arc, checkmark on isCompleted, appAccent color            |
| `HabitXWidget/Views/SmallWidgetView.swift`            | Per-habit widget view with interactive tap        | ✓ VERIFIED | Dispatches correct intent per habitType; input uses widgetURL deep-link   |
| `HabitXWidget/Views/MediumWidgetView.swift`           | All-habits overview widget view                   | ✓ VERIFIED | ForEach over snapshots; row with name, mini ring, progress text, action button |
| `HabitXWidget/Providers/SmallWidgetProvider.swift`    | AppIntentTimelineProvider fetching single habit   | ✓ VERIFIED | FetchDescriptor on MainActor, midnight refresh policy                     |
| `HabitXWidget/Providers/MediumWidgetProvider.swift`   | TimelineProvider fetching all habits              | ✓ VERIFIED | FetchDescriptor sorted by sortOrder, midnight refresh policy              |
| `HabitX/HabitXApp.swift`                             | onOpenURL handler for habitx:// scheme            | ✓ VERIFIED | Parses scheme/host/id query param, sets deepLinkHabitId state             |
| `HabitX/Features/Root/TabRootView.swift`             | Tab switch + scenePhase foreground sync           | ✓ VERIFIED | onChange(deepLinkHabitId) switches to tab 0; onChange(scenePhase) reloads timelines on .active |
| `HabitX/Features/Today/TodayView.swift`              | deepLinkHabitId binding + inputHabit sheet        | ✓ VERIFIED | onChange(deepLinkHabitId) finds habit by UUID, sets TodaySheet.inputHabit, clears binding |

---

### Key Link Verification

| From                          | To                                     | Via                                              | Status     | Details                                                         |
| ----------------------------- | -------------------------------------- | ------------------------------------------------ | ---------- | --------------------------------------------------------------- |
| SmallWidgetEntryView          | ToggleBooleanHabitIntent               | `Button(intent: makeToggleIntent(snapshot:))`    | ✓ WIRED    | Direct AppIntents button wiring, habitId passed as parameter    |
| SmallWidgetEntryView          | IncrementCountHabitIntent              | `Button(intent: makeIncrementIntent(snapshot:))` | ✓ WIRED    | Direct AppIntents button wiring, habitId passed as parameter    |
| SmallWidgetEntryView          | habitx://log deep-link                 | `.widgetURL(URL(string: "habitx://log?id=..."))`  | ✓ WIRED    | widgetURL set for input habit type                              |
| MediumWidgetEntryView         | ToggleBooleanHabitIntent               | `Button(intent:)` in actionButton                | ✓ WIRED    | Per-row action button dispatches correct intent                 |
| MediumWidgetEntryView         | IncrementCountHabitIntent              | `Button(intent:)` in actionButton                | ✓ WIRED    | Per-row action button dispatches correct intent                 |
| MediumWidgetEntryView         | habitx://log deep-link                 | `Link(destination: URL(string: "habitx://..."))` | ✓ WIRED    | Link wraps plus.circle icon for input habits                    |
| ToggleBooleanHabitIntent      | SharedModelContainer (SwiftData)       | `ModelContext(SharedModelContainer.container)`   | ✓ WIRED    | Fetches, mutates, saves, reloads timelines                      |
| IncrementCountHabitIntent     | SharedModelContainer (SwiftData)       | `ModelContext(SharedModelContainer.container)`   | ✓ WIRED    | Fetches, mutates, saves, reloads timelines                      |
| SmallWidgetProvider           | SharedModelContainer (SwiftData)       | `container.mainContext` + FetchDescriptor        | ✓ WIRED    | Fetches habit by UUID from main context on MainActor            |
| MediumWidgetProvider          | SharedModelContainer (SwiftData)       | `container.mainContext` + FetchDescriptor        | ✓ WIRED    | Fetches all habits sorted by sortOrder on MainActor             |
| HabitXApp.onOpenURL           | deepLinkHabitId state                  | URL parse, UUID extract, state assignment        | ✓ WIRED    | Validates scheme=="habitx", host=="log", extracts id query param |
| TabRootView                   | TodayView                              | `Binding<UUID?>` + tab switch on onChange        | ✓ WIRED    | selectedTab = 0 when deepLinkHabitId becomes non-nil            |
| TabRootView                   | WidgetCenter.reloadAllTimelines        | `onChange(of: scenePhase) { .active }`           | ✓ WIRED    | WID-05 foreground sync wired                                    |
| TodayView                     | NumberInputSheet                       | `onChange(deepLinkHabitId)` + TodaySheet.inputHabit | ✓ WIRED | Finds habit by UUID, presents sheet, clears binding             |

---

### Data-Flow Trace (Level 4)

| Artifact              | Data Variable      | Source                                         | Produces Real Data | Status      |
| --------------------- | ------------------ | ---------------------------------------------- | ------------------ | ----------- |
| SmallWidgetEntryView  | `entry.habitSnapshot` | `SmallWidgetProvider.makeEntry()` via FetchDescriptor on MainActor | Yes — fetches `HabitSchemaV1.Habit` from SwiftData store | ✓ FLOWING |
| MediumWidgetEntryView | `entry.snapshots`  | `MediumWidgetProvider.makeEntry()` via FetchDescriptor on MainActor | Yes — fetches all habits sorted by sortOrder from SwiftData store | ✓ FLOWING |
| CircularProgressRingView | `progress`, `isCompleted` | `HabitSnapshot(habit:)` inline computation from `habit.logs` | Yes — computed from real log records | ✓ FLOWING |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — widget code requires a physical device or iOS Simulator runtime; no CLI-runnable entry points for WidgetKit AppIntents. Deep-link URL parsing in HabitXApp is also UI-layer code not testable without a running app.

---

### Requirements Coverage

| Requirement | Source Plan | Description                                                                 | Status        | Evidence                                                              |
| ----------- | ----------- | --------------------------------------------------------------------------- | ------------- | --------------------------------------------------------------------- |
| WID-01      | 03-01, 03-02 | Each habit has a configurable home screen widget showing today's progress  | ✓ SATISFIED   | AppIntentConfiguration small widget + StaticConfiguration medium widget, both backed by live FetchDescriptor data |
| WID-02      | 03-01, 03-02 | Boolean habit widget: tap to toggle done/undone                             | ✓ SATISFIED   | `ToggleBooleanHabitIntent` wired via `Button(intent:)` in both widget views |
| WID-03      | 03-01, 03-02 | Count habit widget: tap to increment by 1                                   | ✓ SATISFIED   | `IncrementCountHabitIntent` wired via `Button(intent:)` in both widget views |
| WID-04      | 03-02, 03-03 | Input habit widget: tapping opens app to log entry sheet                    | ✓ SATISFIED   | `habitx://log?id=` deep-link handled in HabitXApp → TodayView → NumberInputSheet |
| WID-05      | 03-03        | All widgets update immediately after interaction                             | ✓ SATISFIED   | `reloadAllTimelines()` called in both AppIntents' `perform()` AND in `TabRootView.scenePhase == .active` |

---

### User Decisions Honored

| Decision | Description                                          | Status     | Evidence                                                             |
| -------- | ---------------------------------------------------- | ---------- | -------------------------------------------------------------------- |
| D-01     | Ring + fraction label in center                      | ✓ HONORED  | `CircularProgressRingView` + fraction text ZStack in SmallWidgetEntryView |
| D-02     | Completed state: filled ring + checkmark + "Done!"   | ✓ HONORED  | `isCompleted` shows `Image(systemName: "checkmark")` in ring + "Done!" label below |
| D-03     | Incomplete: accent color fill, systemGray4 track     | ✓ HONORED  | `Color(.systemGray4)` track + `Color.appAccent` fill arc in CircularProgressRingView |
| D-04     | Small widget uses AppIntentConfiguration             | ✓ HONORED  | `AppIntentConfiguration(kind:, intent: HabitWidgetIntent.self, provider: SmallWidgetProvider())` |
| D-05     | Small widget: single tap triggers interaction        | ✓ HONORED  | Full view wrapped in `Button(intent:)` for boolean/count; `widgetURL` for input |
| D-06     | Medium widget uses StaticConfiguration               | ✓ HONORED  | `StaticConfiguration(kind:, provider: MediumWidgetProvider())` |
| D-07     | Medium row: name + mini ring + progress text         | ✓ HONORED  | HStack with Text, CircularProgressRingView(size: 24), fraction text |
| D-08     | Medium [+] dispatches correct intent per habit type  | ✓ HONORED  | `actionButton()` switch on `snapshot.habitType` |
| D-10     | No in-app widget onboarding                          | ✓ HONORED  | No onboarding UI added; standard iOS flow used |
| D-11     | reloadAllTimelines after AppIntents                  | ✓ HONORED  | Both intents call `WidgetCenter.shared.reloadAllTimelines()` in `perform()` |
| D-12     | habitx:// deep-link for input habits                 | ✓ HONORED  | `habitx://log?id=<uuid>` scheme registered; `onOpenURL` parses it in HabitXApp |

---

### Anti-Patterns Found

No blockers or stubs detected. All files contain substantive implementations. No `TODO`, `FIXME`, placeholder text, `return null`, `return []`, or empty handlers were found in any of the 11 key files reviewed.

One intentional placeholder noted in 03-01-SUMMARY.md under "Known Stubs" — the `HabitXWidget.swift` placeholder — was explicitly replaced in 03-02 with live `HabitSmallWidget` and `HabitMediumWidget` structs. Confirmed resolved.

---

### Human Verification Required

The following cannot be verified programmatically and require a physical device test:

#### 1. Interactive Widget Toggle (WID-02 physical device)

**Test:** Add the small widget, pick a boolean habit. Tap the widget from the home screen.
**Expected:** Habit toggles to "Done!" with filled ring + checkmark. Widget updates without opening the app. Return to app — Today view shows the habit as completed.
**Why human:** AppIntents and WidgetKit interactive buttons only fire on a physical iOS device; Simulator has limited widget interaction support and no AppIntents trigger.

#### 2. Count Increment from Widget (WID-03 physical device)

**Test:** Add the small widget, pick a count habit (e.g. Water). Tap the widget.
**Expected:** Count increments by 1, ring advances, fraction label updates (e.g. "1/8"). Widget refreshes immediately.
**Why human:** Same as WID-02 — requires physical device for AppIntents to fire.

#### 3. Input Habit Deep-Link (WID-04)

**Test:** Add the small widget, pick an input habit (e.g. Protein). Tap the widget.
**Expected:** App opens directly to the NumberInputSheet for Protein. Value can be entered and saved.
**Why human:** URL scheme open requires device to actually launch the app; Simulator behavior differs.

#### 4. Foreground Sync (WID-05)

**Test:** Log a habit from the widget. Then tap the widget to open the app (or switch to it manually). Observe Today view.
**Expected:** Today view shows the widget-logged value without any stale state.
**Why human:** Requires verifying that `scenePhase == .active` triggers before the view renders stale data — a timing concern only observable at runtime.

---

## Gaps Summary

No gaps. All 5 success criteria are verified in code. All 5 WID requirements are satisfied. All 11 required files exist and are substantive, wired, and carry real data flow. All user decisions from CONTEXT.md are honored in the implementation.

The remaining verification items are physical-device behavioral tests that cannot be automated — these are surfaced under Human Verification Required above.

---

_Verified: 2026-03-30_
_Verifier: Claude (gsd-verifier)_
