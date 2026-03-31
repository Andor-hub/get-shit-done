# Project Research Summary

**Project:** HabitX 2.0
**Domain:** Native iOS habit tracking app — widget-first, minimalist, local-only v1
**Researched:** 2026-03-27
**Confidence:** HIGH

---

## Executive Summary

HabitX 2.0 is a native iOS habit tracker whose entire value proposition rests on a single interaction: tapping a home screen widget to log a habit without opening the app. This is achievable and well-documented using iOS 17's AppIntents-powered interactive widgets. The full stack is Apple-first with zero anticipated third-party dependencies — SwiftUI, SwiftData, WidgetKit, AppIntents, UserNotifications, and Swift Charts cover every requirement. The minimum iOS deployment target is iOS 17.0, which is non-negotiable because interactive widgets, SwiftData, and the `@Observable` macro all gate on that version. iOS 17+ adoption is above 90% of active devices as of early 2026, so this cuts no meaningful audience.

The recommended architecture is MVVM with `@Observable` (iOS 17 style), SwiftData for on-device persistence, and App Groups to share the SQLite store between the main app target and the widget extension. The data model is simple: two `@Model` types (Habit and HabitLog), three habit types (boolean, count, input), and a single `Double` value field on every log entry. This avoids polymorphic complexity while satisfying all use cases. The architecture research provides a confirmed build order — infrastructure and data layer first, widget display before widget interactivity — that eliminates common rework.

The critical risk profile for this project is almost entirely in Phase 1 setup. Four pitfalls — missing VersionedSchema, missing App Groups on both targets, non-optional model fields that block future CloudKit, and Debug/Release entitlement drift — all manifest silently at or before first TestFlight. None of them are hard to prevent; all of them are catastrophic to fix retroactively. Getting Phase 1 right means the remainder of the project follows well-documented patterns with high confidence.

---

## Key Findings

### Recommended Stack

The stack is entirely Apple frameworks. There is no justified reason to add any third-party dependency in v1. SwiftUI is mandatory because WidgetKit views are SwiftUI-only — using UIKit in the main app and SwiftUI in the widget creates two codebases with no benefit. SwiftData, not CoreData, is correct for a greenfield iOS 17+ app with a simple two-entity schema.

**Core technologies:**
- **Swift 6.1 (Xcode 16.3)** — primary language; Swift 6 strict concurrency mode from project start; upgrade to 6.2 when Xcode 17 ships
- **SwiftUI (iOS 17+ API surface)** — all app UI and all widget views; mandatory given WidgetKit is SwiftUI-only
- **`@Observable` macro** — ViewModel layer; replaces ObservableObject/Combine with fine-grained view invalidation and less boilerplate
- **SwiftData (iOS 17+)** — on-device persistence; store in App Group container from day one; `@Model` files added to both targets
- **WidgetKit + AppIntents (iOS 17+)** — interactive home screen widgets; `AppIntentTimelineProvider`; `ToggleHabitIntent` and `IncrementHabitIntent` for boolean and count types
- **UserNotifications (UNUserNotificationCenter)** — per-habit daily reminders; `UNCalendarNotificationTrigger` with `repeats: true` (one slot per habit)
- **Swift Charts** — bundled with SwiftUI; covers all stats visualization without any external dependency
- **Swift Testing (`@Test`, `#expect`)** — unit tests; XCTest reserved for UI automation only
- **Xcode 16.3+, SPM** — build tooling; CocoaPods and Carthage are not the answer

**iOS deployment target: 17.0** — hard floor driven by interactive widgets, SwiftData, and `@Observable`. No exceptions.

### Expected Features

**Must have at launch (table stakes):**
- Daily habit logging (boolean tap, count increment, input value via app deep-link)
- Streak tracking — current streak and best streak per habit
- Today view — consolidated list of all habits and current status
- History / completion log — scrollable per-habit calendar or list view
- Per-habit push notifications — local, single daily reminder at user-chosen time
- Interactive home screen widget per habit — small and medium families; iOS 17 AppIntents
- Basic stats — completion rate, streak length, total completions
- Habit CRUD — name, type, target, reminder time
- Dark mode — automatic via SwiftUI
- Non-punitive missed-day handling — neutral display, best streak preserved

**Should have (competitive differentiators):**
- Interactive widget tap-to-complete without opening the app — this is the core value proposition, not optional
- Three habit types (boolean / count / input) — closes the gap Streaks leaves with count/input
- Progress ring visual on widget — instant at-a-glance completion status
- Curated default habits (Protein, Water) ready from first launch — eliminates onboarding friction
- Per-habit widget configuration — lets users place specific habits in context-relevant locations
- Frictionless onboarding — first habit visible and loggable within 2 minutes of install

**Defer to v2+ with confidence:**
- iCloud / CloudKit sync — architecture supports it; design models now to make it easy later
- Apple Watch app — separate WidgetKit track; significant scope
- Apple Health integration — HealthKit entitlement complexity for minimal v1 benefit
- Lock screen widgets — additive post-launch
- Social / friends features — requires auth and backend; entire second product
- Gamification (badges, XP, levels) — wrong identity for this product
- Subscription monetization — top complaint across category; evaluate one-time purchase model

### Architecture Approach

The architecture is MVVM with `@Observable` ViewModels, SwiftData models shared via App Group container, and a clean boundary between the main app target and the widget extension. The most critical structural decision is `SharedModelContainer` — a static singleton that both targets instantiate from the same App Group store URL. Both `@Model` files (Habit, HabitLog) must be members of both Xcode targets. The widget reads from the shared store via `HabitTimelineProvider` and writes back via `AppIntent.perform()` which then triggers `WidgetCenter.shared.reloadAllTimelines()`. Timeline entries use value-type snapshots, never live `@Model` references.

**Major components:**
1. **SwiftUI Views (app)** — Today, History, Stats, Settings; render only, delegate actions to ViewModels
2. **ViewModels (`@Observable`)** — TodayVM, HabitDetailVM, StatsVM; business logic, streak math, coordinate persistence and notification scheduling
3. **SwiftData Models (`@Model` — both targets)** — Habit, HabitLog; stored in App Group container; all properties with default values for future CloudKit compatibility
4. **NotificationManager** — singleton; schedules/cancels `UNCalendarNotificationTrigger` per habit; rescheduled on app foreground and habit edits
5. **HabitTimelineProvider** — reads from App Group SwiftData store; returns value-type snapshot entries; timeline policy anchored to midnight boundaries
6. **AppIntents (ToggleHabitIntent, IncrementHabitIntent)** — widget button handlers; write to SwiftData via shared container; trigger timeline reload; must be tested on physical device
7. **Widget Views** — SwiftUI-only; small and medium families; `.systemSmall` and `.systemMedium`; display-only for input habits, interactive for boolean/count

### Critical Pitfalls

**Top 5 — all must be addressed before first TestFlight:**

1. **No VersionedSchema on SwiftData models** — Without defining `HabitSchemaV1: VersionedSchema` before shipping, any future schema change causes a crash-on-launch for all existing users with no migration recovery path. Define `SchemaV1` and a `SchemaMigrationPlan` before the first TestFlight build. This is a 30-minute task; skipping it costs days of v2 work and data loss for users.

2. **App Groups not configured on both targets** — If either the main app or the widget extension is missing the App Group entitlement (or uses a different group ID), each process silently creates its own empty SQLite store. The widget shows no data immediately. The fix must happen in Phase 1 before any widget feature work. Verify by running a TestFlight build (not just Simulator) — Debug vs. Release provisioning drift is a known failure mode.

3. **Non-optional model fields block CloudKit** — CloudKit requires all attributes and relationships to be optional or have defaults. Models that use non-optional `String`, `Int`, or `Double` without defaults compile and run locally but silently block CloudKit sync activation. Design all v1 model fields with defaults (`= ""`, `= 0`, `= []`) now to avoid a breaking schema migration when CloudKit is added in v2.

4. **AppIntent `perform()` not called with app backgrounded** — When the main app is running in the background, interactive widget button taps can fail to call `perform()`. This is a device-only bug that Simulator does not reproduce. For iOS 18.4+, evaluate `ForegroundContinuableIntent` conformance. Always test AppIntent flows on a physical device before marking any widget phase complete.

5. **Widget ModelContext staleness after widget writes** — The main app's `ModelContext` in-memory cache does not automatically observe writes made by the widget extension's process. The Today view can show stale data after a widget tap. Mitigation: refresh the context on `scenePhase == .active` transitions; do not rely solely on `@Query` passive observation for correctness on iOS 17.

---

## Implications for Roadmap

The architecture research provides a validated 7-step build order with explicit dependency rationale. This maps cleanly to 4 shipping phases for the roadmap.

### Phase 1: Foundation — Project Setup, Data Model, App Groups

**Rationale:** Everything else depends on infrastructure being correct. Data layer bugs that surface through a widget add unnecessary debugging indirection. The most catastrophic pitfalls (VersionedSchema, App Groups, CloudKit-compatible model design) all live here and cost almost nothing to prevent now.

**Delivers:** Xcode project with two targets, App Group entitlement on both, `SharedModelContainer` singleton, `Habit` and `HabitLog` models with `VersionedSchema`, basic SwiftData CRUD verified in the main app (no UI required), and a TestFlight smoke test confirming the widget extension can read from the shared store.

**Features addressed:** Habit CRUD (add/edit/delete), data persistence

**Pitfalls to nail:** VersionedSchema (P1), App Groups both targets (P2), CloudKit-compatible model defaults (P3), Debug/Release entitlement parity (P13)

**Research flag:** Standard patterns — well-documented. No additional research needed. Execute from the Project Setup Checklist in STACK.md.

---

### Phase 2: Core App — Today View, History, Stats

**Rationale:** Establish a working, testable main app before introducing widget complexity. Once data flows correctly through the main app, adding the widget as a read-only consumer (Phase 3) is straightforward. Building stats before widgets is the right call — StatsVM stress-tests streak math and date boundary logic in isolation before widget timeline generation depends on it.

**Delivers:** Today view with quick-log controls for all three habit types, History view (scrollable per-habit log), Stats view (streak, completion rate, total), non-punitive missed-day display, dark mode, curated default habits (Protein, Water) on first launch, frictionless onboarding flow.

**Features addressed:** All table stakes except widget and notifications

**Pitfalls to nail:** Date boundary / timezone logic (P10) — use `Calendar.current.startOfDay` throughout, never arithmetic offsets. Add unit tests in Swift Testing for streak calculation and day-boundary edge cases.

**Research flag:** Standard patterns — SwiftUI + `@Observable` + SwiftData is well-documented. Streak math is custom business logic worth unit testing with parameterized `@Test(arguments:)` cases.

---

### Phase 3: Widget — Display, then Interactive

**Rationale:** Read-only widget first confirms App Group data sharing works end-to-end before AppIntent writes are introduced. Separating display from interactivity reduces debugging surface area significantly. Interactive buttons require physical device testing — build that into the phase definition.

**Delivers:** Per-habit home screen widget in small and medium families; `HabitTimelineProvider` with midnight boundary timeline policy; read-only display widget (StaticConfiguration) for input habits with deep-link tap to log in app; interactive widgets (AppIntentConfiguration) for boolean and count habits with `ToggleHabitIntent` and `IncrementHabitIntent`; WidgetCenter reload on main app habit log.

**Features addressed:** Interactive home screen widget (the core differentiator), progress ring visual, per-habit widget configuration

**Pitfalls to nail:** AppIntent `perform()` not firing with app backgrounded (P5), widget timeline staleness after tap (P6), ModelContext staleness in main app after widget writes (P7), widget memory 30 MB hard cap (P8), update budget exhaustion from excessive `reloadAllTimelines()` calls (P11). Physical device test is a gate before phase sign-off.

**Research flag:** Needs careful implementation — multiple device-only failure modes with no Simulator feedback. The phase-specific warnings table in PITFALLS.md should be used as a checklist during implementation. No additional deep research needed; all pitfalls are already documented with mitigations.

---

### Phase 4: Notifications + Pre-Submission Polish

**Rationale:** Notifications are independent of widget interactivity and can be built after the core app and widget are solid. Pre-submission tasks (PrivacyInfo manifest, final TestFlight validation) are bundled here because they gate App Store submission, not feature completeness.

**Delivers:** `NotificationManager` singleton; per-habit `UNCalendarNotificationTrigger` with `repeats: true`; contextual permission request (after first habit with reminder is added, not at launch); foreground authorization status check on `scenePhase == .active`; `PrivacyInfo.xcprivacy` manifest for both targets; final TestFlight regression on widget + notifications + data persistence.

**Features addressed:** Per-habit push notifications (table stakes)

**Pitfalls to nail:** 64-notification slot limit (P9) — `repeats: true` keeps each habit at one slot; foreground authorization re-check (P12); Privacy Manifest for App Store submission (P14).

**Research flag:** Standard patterns — UserNotifications is stable and thoroughly documented. Privacy Manifest is boilerplate that requires no research, just execution.

---

### Phase Ordering Rationale

- **Infrastructure before features:** App Groups and VersionedSchema cannot be retrofitted without user-facing data loss. Configuring them last is the highest-risk mistake in this category.
- **Main app before widget:** Data integrity bugs found in the main app are easier to diagnose and fix before they're being observed through a widget extension in a separate process.
- **Display before interactive widget:** Read-only widget validates the App Group store sharing. AppIntents add a write-back path and device-only failure modes — introducing both simultaneously makes root cause analysis harder.
- **Notifications last:** UNUserNotificationCenter does not depend on widgets being complete. Deferring it avoids notification permission prompts during earlier test phases and keeps Phase 1-3 focused on the core loop.
- **CloudKit deferred:** The architecture is explicitly designed to make CloudKit a non-breaking addition. The migration path is: add `cloudKitDatabase` to `ModelConfiguration`, add iCloud capability to main target. No model changes required if Phase 1 defaults are in place.

---

### Research Flags

**Phases with standard patterns (skip research-phase):**
- **Phase 1:** Xcode project setup, App Groups, SwiftData schema versioning — all steps are in Apple documentation and confirmed via STACK.md checklist
- **Phase 2:** SwiftUI MVVM with `@Observable`, SwiftData CRUD — well-documented; streak math is custom logic not requiring research
- **Phase 4:** UserNotifications, Privacy Manifest — both are stable, well-documented APIs

**Phases that need careful implementation attention (not research, but vigilance):**
- **Phase 3 (Widget interactivity):** Not a research gap — all failure modes are documented in PITFALLS.md. The risk is implementation execution, not unknown patterns. Use the phase-specific warnings table as a sign-off checklist and mandate physical device testing as a gate.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All core technologies are Apple-first with official WWDC documentation and confirmed release dates. Zero ambiguity on the chosen stack. |
| Features | MEDIUM-HIGH | Table stakes and differentiators derived from App Store reviews, competitive analysis, and habit psychology research. Competitor internals (e.g., exact Streaks widget behavior) are inferred. Main risk is unknown user preference, not factual error. |
| Architecture | HIGH | Patterns verified against Apple Developer Forums, official WidgetKit docs, and multiple cross-referenced implementation guides. SharedModelContainer pattern and AppIntent data flow are confirmed. |
| Pitfalls | HIGH | All critical pitfalls are sourced from Apple Developer Forums threads documenting real production failures, Apple feedback reports, and official documentation. No speculative pitfalls included. |

**Overall confidence: HIGH**

### Gaps to Address

- **Monetization model:** FEATURES.md recommends one-time purchase over subscription (matches Streaks' praised model, avoids top complaint), but the final pricing decision is not resolved. Decide before App Store submission — it affects App Store listing setup, not code.
- **Onboarding flow specifics:** Research confirms that getting the user to log their first habit in session 1 is critical for retention, and that Protein and Water are the right default habits. The exact onboarding screen sequence is unspecified and should be sketched before Phase 2 UI work begins.
- **Widget configuration UX:** Research confirms per-habit widgets (not combined) are the right model. How users select which habit to assign to a widget placement (via WidgetKit's built-in configuration UI or a custom `AppIntentConfiguration` parameter) needs a design decision before Phase 3.
- **iOS 18.4 `ForegroundContinuableIntent`:** PITFALLS.md flags this as a potential requirement for AppIntents on iOS 18.4+. This should be evaluated during Phase 3 once device testing reveals whether `perform()` routing is an issue on the test device's iOS version.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — WidgetKit, AppIntents, SwiftData, UNUserNotificationCenter
- WWDC23 "Bring widgets to life" — interactive widget AppIntents requirements
- WWDC23 "Meet SwiftData" — SwiftData architecture and App Group integration
- Swift.org release notes — Swift 6.1 (March 2025), Swift 6.2 (September 2025)
- Apple Developer Forums — App Groups + SwiftData (thread/732986, thread/789173), AppIntent routing (thread/732771), VersionedSchema migration (thread/761735), CloudKit + custom migration crash (thread/744491)
- HackingWithSwift — SwiftData with widgets (confirmed against Apple docs patterns)
- mertbulan.com / azamsharp.com — VersionedSchema requirement (confirmed against Apple Forums)

### Secondary (MEDIUM confidence)
- App Store competitive analysis — Streaks, Done, Habitica, Way of Life, Finch
- The Sweet Setup, Cohorty, Widgetly — habit tracker category reviews
- BJ Fogg Behavior Model — habit psychology design implications
- DEV Community — iOS Widget Interactivity 2026, streak psychology, guilt-loop pattern analysis
- Medium / Kodeco — MVVM 2025 patterns, interactive widget implementation guides

### Tertiary (LOW confidence)
- Fhynix.com — user research aggregation (not independently verified)
- Widgetly Blog — marketing blog; used only for feature landscape triangulation

---

*Research completed: 2026-03-27*
*Ready for roadmap: yes*
