# Phase 3: Widgets - Research

**Researched:** 2026-03-30
**Domain:** WidgetKit + AppIntents + SwiftData (iOS 17+)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Progress indicator: circular progress ring with fraction label in center (e.g. "3/8" for Water, "50/150g" for Protein). Habit name above, unit below.
- **D-02:** Completed state: ring fills fully in accent color, fraction replaced by checkmark (✓), label below changes to "Done!".
- **D-03:** Incomplete state: app accent color for filled ring portion; system gray for unfilled portion.
- **D-04:** Small widget uses AppIntentConfiguration — user picks habit via iOS widget edit mode.
- **D-05:** Small widget layout: habit name top, ring + fraction center, unit label bottom. Single tap triggers interaction.
- **D-06:** Medium widget is StaticConfiguration — automatically shows all habits.
- **D-07:** Medium widget row layout: `[habit name]  [mini ring]  [progress text]  [+]`
- **D-08:** Medium widget [+]: boolean = toggle, count = +1, input = deep-link to log sheet.
- **D-09:** Completed habits in overview still show ✓; [+] button remains visible.
- **D-10:** No in-app widget onboarding UI.
- **D-11 (Claude's discretion):** After AppIntent action, call `WidgetCenter.shared.reloadAllTimelines()`. Main app also calls this after any logging action.
- **D-12 (Claude's discretion):** Input habit widgets use URL scheme (`habitx://log?id=<habitId>`) deep-link to open NumberInputSheet.

### Claude's Discretion

- **D-11:** WidgetCenter reload strategy (decided: reloadAllTimelines after every action).
- **D-12:** Deep-link mechanism for input habits (decided: URL scheme + onOpenURL).

### Deferred Ideas (OUT OF SCOPE)

- Lock screen widgets (WID-06)
- Large overview widget
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WID-01 | Each habit has a configurable home screen widget (small + medium families) showing today's progress | AppIntentConfiguration + AppEntityQuery for small; StaticConfiguration for medium; FetchDescriptor in timeline() for habit data |
| WID-02 | Boolean habit widget: tap to toggle done/undone (interactive) | `Button(intent: ToggleBooleanHabitIntent(habitId:))` in widget view; AppIntent writes via ModelContext from SharedModelContainer.container |
| WID-03 | Count habit widget: tap to increment by 1 (interactive) | `Button(intent: IncrementCountHabitIntent(habitId:))` in widget view; same write pattern as WID-02 |
| WID-04 | Input habit widget: tapping opens app to log entry sheet | `.widgetURL(URL(string: "habitx://log?id=\(habit.id)")!)` on small widget; `Link` or `Button(intent: OpenInputHabitIntent(habitId:))` on medium; `onOpenURL` in HabitXApp.swift |
| WID-05 | All widgets update immediately after interaction | Interacted widget gets one guaranteed immediate reload when AppIntent.perform() returns; call `WidgetCenter.shared.reloadAllTimelines()` from main app after any HabitLogService call |
</phase_requirements>

---

## Summary

Phase 3 builds WidgetKit home screen widgets for HabitX using the full iOS 17+ AppIntents API stack. There are two distinct widget types: a per-habit small widget using `AppIntentConfiguration` (with a `WidgetConfigurationIntent` + `AppEntityQuery` that lets users pick a habit in widget edit mode), and an all-habits medium overview widget using `StaticConfiguration`. Both widget types share the same SwiftData store via the established App Group (`group.com.habitx.shared`).

The interactive behavior — boolean toggle, count increment — is implemented with `Button(intent:)` in SwiftUI widget views backed by `AppIntent` structs. Each `AppIntent.perform()` creates a `ModelContext` from `SharedModelContainer.container` (the shared global), writes the log change, and returns. The interacted widget receives one guaranteed immediate reload when `perform()` returns; `WidgetCenter.shared.reloadAllTimelines()` is called afterward to update other widget instances. Input habits cannot accept text in a widget (iOS platform constraint); they use a `widgetURL` / URL scheme deep-link to open the app.

The SwiftData `@Query` property wrapper is unavailable in `TimelineProvider` methods. Timeline providers must fetch via `FetchDescriptor` on `SharedModelContainer.container.mainContext`. The existing `SharedModelContainer` is already correctly wired with the App Group URL, so no container changes are needed. AppIntent target membership must include both the app target and the widget extension target.

**Primary recommendation:** Use `AppIntentConfiguration` for the small widget with a lightweight `HabitEntity` wrapper (not direct `@Model` conformance), and use `Button(intent:)` in widget views for interactive actions with a single `ModelContext(SharedModelContainer.container)` in each `perform()`.

---

## Project Constraints (from CLAUDE.md)

- **Platform:** Native iOS (Swift/SwiftUI) only, iOS 17+ minimum
- **Widget interactivity:** iOS 17+ required; `AppIntentTimelineProvider` replaces `IntentTimelineProvider`; `Button`/`Toggle` with `AppIntent` initializers
- **Text input in widgets:** NOT supported — input habits must deep-link into app (confirmed platform constraint)
- **Storage:** SwiftData App Group container from day one (`group.com.habitx.shared`)
- **Widget data sharing:** Both targets share same SQLite store via App Group; `SharedModelContainer.container` is the canonical instance
- **Swift version:** Swift 6.1, Xcode 16.3+, SWIFT_STRICT_CONCURRENCY = complete
- **Simplicity:** Minimal friction. Every widget decision should reduce friction.
- **GSD Workflow:** All changes via GSD commands; no direct repo edits outside workflow

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WidgetKit | iOS 17+ (bundled) | Widget timeline, entry view, Widget struct | Only supported iOS home screen widget framework |
| AppIntents | iOS 17+ (bundled) | Interactive widget actions, configurable widget picker | Required for Button(intent:) and AppIntentConfiguration — no alternative |
| SwiftData | iOS 17+ (bundled) | Shared on-device persistence (already set up) | Existing project choice; App Group container already configured |
| SwiftUI | iOS 17+ (bundled) | All widget views | WidgetKit views are SwiftUI-only |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| WidgetCenter | iOS 14+ (bundled) | Trigger timeline reload from app and from AppIntent | After every log action in main app and after AppIntent.perform() |
| Foundation (URL) | iOS 17+ (bundled) | URL scheme deep-links for input habits | widgetURL modifier and onOpenURL handler |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| URL scheme deep-link | `OpenURLIntent` (AppIntents) | OpenURLIntent opens a URL from within an intent; for small widgets widgetURL is simpler and avoids extra intent type |
| Separate AppEntity struct | Direct @Model AppEntity conformance | @Model classes have PersistentModel synthesis that conflicts with AppEntity ID requirements — separate lightweight struct is cleaner and avoids linker issues across targets |
| `reloadAllTimelines()` from perform() | `requestUpdate()` (iOS 18+ only) | requestUpdate is iOS 18+; project targets iOS 17+; reloadAllTimelines is the correct API for this deployment target |

**Installation:** No new packages required. All APIs are Apple system frameworks already linked in both targets.

---

## Architecture Patterns

### Recommended File Structure (widget extension target)

```
HabitX/HabitXWidget/
├── HabitXWidget.swift              # REPLACE — two Widget structs: HabitSmallWidget + HabitMediumWidget
├── HabitXWidgetBundle.swift        # UPDATE — add HabitMediumWidget() to bundle body
├── Intents/
│   ├── HabitEntity.swift           # NEW — AppEntity wrapping Habit data
│   ├── HabitEntityQuery.swift      # NEW — EntityQuery + suggestedEntities() via SwiftData fetch
│   ├── HabitWidgetIntent.swift     # NEW — WidgetConfigurationIntent for small widget
│   ├── ToggleBooleanHabitIntent.swift   # NEW — AppIntent: toggle boolean
│   └── IncrementCountHabitIntent.swift  # NEW — AppIntent: increment count
├── Views/
│   ├── CircularProgressRingView.swift   # NEW — reusable ring component
│   ├── SmallWidgetView.swift            # NEW — small widget entry view
│   └── MediumWidgetView.swift           # NEW — medium widget entry view
└── Providers/
    ├── SmallWidgetProvider.swift         # NEW — AppIntentTimelineProvider
    └── MediumWidgetProvider.swift        # NEW — TimelineProvider (StaticConfiguration)
```

Files shared between app + widget targets (already in both):
- `HabitX/HabitX/Models/Schema/HabitSchemaV1.swift`
- `HabitX/HabitX/Models/SharedModelContainer.swift`
- `HabitX/HabitX/Models/Schema/HabitMigrationPlan.swift`
- `HabitX/HabitX/Utilities/HabitDefaults.swift` (Color.appAccent — must be added to widget target if not already)

### Pattern 1: AppEntity Wrapper for Habit

**What:** A lightweight value-type `HabitEntity` that wraps the minimal data needed for widget configuration UI. Does NOT make `@Model` directly conform to `AppEntity` (causes linker issues when the @Model file spans both targets).

**When to use:** For the `AppIntentConfiguration` picker — iOS reads `suggestedEntities()` to populate the dropdown in widget edit mode.

```swift
// Source: appmakers.dev configurable widget guide (verified pattern)
import AppIntents

struct HabitEntity: AppEntity {
    // Use the habit's UUID (not PersistentIdentifier) for stable cross-process identity
    var id: UUID
    var name: String
    var habitType: String  // raw value from HabitType enum
    var unit: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Habit")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = HabitEntityQuery()
}
```

### Pattern 2: HabitEntityQuery — SwiftData fetch from AppEntityQuery

**What:** `EntityQuery` conformance that fetches `Habit` records from the shared SwiftData container and maps them to `HabitEntity` values.

**Key constraint:** Must use `@MainActor` when accessing `SharedModelContainer.container.mainContext`.

```swift
// Source: nicoladefilippo.com + appmakers.dev (verified pattern)
struct HabitEntityQuery: EntityQuery {
    @MainActor
    func suggestedEntities() async throws -> [HabitEntity] {
        let context = SharedModelContainer.container.mainContext
        let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let habits = try context.fetch(descriptor)
        return habits.map { habit in
            HabitEntity(
                id: habit.id,
                name: habit.name,
                habitType: habit.habitType,
                unit: habit.unit
            )
        }
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        let context = SharedModelContainer.container.mainContext
        let ids = identifiers
        let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let habits = try context.fetch(descriptor)
        return habits.map { habit in
            HabitEntity(id: habit.id, name: habit.name,
                        habitType: habit.habitType, unit: habit.unit)
        }
    }
}
```

### Pattern 3: WidgetConfigurationIntent for Small Widget

**What:** The intent type that combines widget configuration parameters. The user sees a single "Habit" parameter dropdown in widget edit mode.

```swift
// Source: Alexander Weiss blog (appintents-for-widgets, verified pattern)
import AppIntents

struct HabitWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Habit"
    static var description = IntentDescription("Choose a habit to track.")

    @Parameter(title: "Habit")
    var habit: HabitEntity?
}
```

### Pattern 4: AppIntentTimelineProvider (small widget)

**What:** Async timeline provider that reads the selected habit's current log data to build a `HabitWidgetEntry`.

**Key constraint:** `@MainActor` needed when accessing `mainContext`. The `AppIntentTimelineProvider` methods are async (no completion handlers) — this is the iOS 17+ API.

```swift
// Source: appmakers.dev + Alexander Weiss blog (verified pattern)
struct SmallWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = HabitWidgetIntent
    typealias Entry = HabitWidgetEntry

    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry(date: .now, habitSnapshot: nil)
    }

    func snapshot(for configuration: HabitWidgetIntent, in context: Context) async -> HabitWidgetEntry {
        await makeEntry(for: configuration.habit)
    }

    func timeline(for configuration: HabitWidgetIntent, in context: Context) async -> Timeline<HabitWidgetEntry> {
        let entry = await makeEntry(for: configuration.habit)
        // Refresh at start of next day (midnight) — habits reset daily
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        return Timeline(entries: [entry], policy: .after(midnight))
    }

    @MainActor
    private func makeEntry(for entity: HabitEntity?) async -> HabitWidgetEntry {
        guard let entity else {
            return HabitWidgetEntry(date: .now, habitSnapshot: nil)
        }
        let context = SharedModelContainer.container.mainContext
        let id = entity.id
        let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
            predicate: #Predicate { $0.id == id }
        )
        guard let habit = try? context.fetch(descriptor).first else {
            return HabitWidgetEntry(date: .now, habitSnapshot: nil)
        }
        let snapshot = HabitSnapshot(habit: habit)
        return HabitWidgetEntry(date: .now, habitSnapshot: snapshot)
    }
}
```

### Pattern 5: TimelineEntry with HabitSnapshot

**What:** The entry carries a `HabitSnapshot` value type so the widget view doesn't need to re-fetch. Using a value type avoids SwiftData @Model crossing concurrency boundaries.

```swift
// Timeline entry
struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    let habitSnapshot: HabitSnapshot?
}

// Snapshot — value type captures everything the view needs at render time
struct HabitSnapshot: Sendable {
    let id: UUID
    let name: String
    let habitType: HabitType
    let unit: String
    let dailyTarget: Double
    let todayValue: Double
    let isCompleted: Bool

    init(habit: HabitSchemaV1.Habit) {
        id = habit.id
        name = habit.name
        habitType = HabitType(rawValue: habit.habitType) ?? .boolean
        unit = habit.unit
        dailyTarget = habit.dailyTarget
        todayValue = HabitLogService.todayValue(for: habit)
        isCompleted = HabitLogService.isCompleted(habit: habit)
    }
}
```

### Pattern 6: AppIntent for Write Actions

**What:** Discrete `AppIntent` types for each interactive action. Each creates its own `ModelContext` from `SharedModelContainer.container`, performs the write (reusing `HabitLogService` logic inline since the service is `@MainActor` and takes explicit context), then calls `WidgetCenter.shared.reloadAllTimelines()`.

**Target membership:** AppIntent files must be added to BOTH the app target AND the widget extension target in Xcode so Siri/Shortcuts and widgets can both discover them.

```swift
// Source: appmakers.dev (verified pattern)
import AppIntents
import SwiftData
import WidgetKit

struct ToggleBooleanHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Habit"

    @Parameter(title: "Habit ID")
    var habitId: String  // UUID as string (AppIntent @Parameter supports String, not UUID)

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = ModelContext(SharedModelContainer.container)
        let idStr = habitId
        let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
            predicate: #Predicate { $0.id.uuidString == idStr }
        )
        guard let habit = try? context.fetch(descriptor).first else {
            return .result()
        }
        // Inline HabitLogService.toggleBoolean logic (service is @MainActor-compatible)
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = habit.logs.first(where: { $0.date >= today }) {
            context.delete(existing)
        } else {
            let log = HabitSchemaV1.HabitLog()
            log.date = today; log.value = 1.0; log.habit = habit
            context.insert(log)
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct IncrementCountHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment Habit"

    @Parameter(title: "Habit ID")
    var habitId: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = ModelContext(SharedModelContainer.container)
        let idStr = habitId
        let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
            predicate: #Predicate { $0.id.uuidString == idStr }
        )
        guard let habit = try? context.fetch(descriptor).first else {
            return .result()
        }
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = habit.logs.first(where: { $0.date >= today }) {
            existing.value += 1.0
            existing.loggedAt = Date()
        } else {
            let log = HabitSchemaV1.HabitLog()
            log.date = today; log.value = 1.0; log.habit = habit
            context.insert(log)
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

### Pattern 7: Circular Progress Ring View

**What:** Reusable SwiftUI view using `ZStack` + `Circle().trim()`. Works in both widget and app contexts. Rotation by -90 degrees starts progress at 12 o'clock.

```swift
// Source: sarunw.com circular progress bar (verified pattern)
struct CircularProgressRingView: View {
    let progress: Double   // 0.0 to 1.0 (clamp: min(value/target, 1.0))
    let isCompleted: Bool
    let size: CGFloat      // outer diameter

    var body: some View {
        ZStack {
            // Track ring (unfilled)
            Circle()
                .stroke(Color(.systemGray4), lineWidth: size * 0.12)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    Color.appAccent,
                    style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center label
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(Color.appAccent)
            } else {
                // Fraction text — caller passes formatted string
            }
        }
        .frame(width: size, height: size)
    }
}
```

### Pattern 8: Deep-Link for Input Habits

**Small widget:** Apply `.widgetURL(URL(string: "habitx://log?id=\(snapshot.id.uuidString)")!)` to the widget's top-level view. Tapping anywhere on a small widget follows this URL.

**Medium widget row:** Use a `Link` view wrapping the row's tappable area, with destination `URL(string: "habitx://log?id=\(snapshot.id.uuidString)")!`. `Link` works on systemMedium and larger.

**In HabitXApp.swift:** Add `.onOpenURL` to `TabRootView`:

```swift
// HabitXApp.swift — add URL scheme in Info.plist CFBundleURLSchemes first
WindowGroup {
    TabRootView()
        .onOpenURL { url in
            // Parse habitx://log?id=<uuid>
            // Set @State on TabRootView to show NumberInputSheet for that habit
        }
}
.modelContainer(SharedModelContainer.container)
```

**Info.plist:** Register `habitx` URL scheme in `CFBundleURLTypes` / `CFBundleURLSchemes`. This is set in the main app target's Info.plist or via xcodegen project.yml.

### Pattern 9: StaticConfiguration for Medium Widget

**What:** The medium overview widget uses `StaticConfiguration` (no user-picking) with `TimelineProvider` (callback-based). It fetches all habits in `getTimeline`.

```swift
struct MediumWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MediumWidgetEntry {
        MediumWidgetEntry(date: .now, snapshots: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (MediumWidgetEntry) -> Void) {
        Task { @MainActor in
            completion(makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MediumWidgetEntry>) -> Void) {
        Task { @MainActor in
            let entry = makeEntry()
            let midnight = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
            )
            completion(Timeline(entries: [entry], policy: .after(midnight)))
        }
    }

    @MainActor
    private func makeEntry() -> MediumWidgetEntry {
        let context = SharedModelContainer.container.mainContext
        let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let habits = (try? context.fetch(descriptor)) ?? []
        let snapshots = habits.map { HabitSnapshot(habit: $0) }
        return MediumWidgetEntry(date: .now, snapshots: snapshots)
    }
}
```

### Pattern 10: Widget Bundle Update

```swift
@main
struct HabitXWidgetBundle: WidgetBundle {
    var body: some Widget {
        HabitSmallWidget()    // AppIntentConfiguration — per-habit
        HabitMediumWidget()   // StaticConfiguration — all habits overview
    }
}
```

Small and medium are separate `Widget` structs with distinct `kind` strings. The `kind` string is stable — changing it breaks existing user widget placements.

### Anti-Patterns to Avoid

- **Using @Query in TimelineProvider:** `@Query` is a SwiftUI property wrapper tied to the view's environment. It is not available in `TimelineProvider` structs. Always use `FetchDescriptor` + `mainContext` instead.
- **Making @Model directly conform to AppEntity:** `@Model` classes have `PersistentModel` conformance synthesized via macros that conflicts with `AppEntity`'s `id` requirement and creates linker issues when the file is in both targets. Use a separate `HabitEntity` value type.
- **Storing @Model instances in TimelineEntry:** `@Model` objects are not `Sendable` and cross process boundaries in widget rendering. Store `HabitSnapshot` value types in entries.
- **Using PersistentIdentifier as AppEntity ID:** `PersistentIdentifier` is not stable across devices or store rebuilds. Use the habit's `UUID` field.
- **Forgetting to add AppIntent files to both targets:** If AppIntent files are only in the widget target, the main app cannot invoke them (needed for Siri/Shortcuts). Both targets need the AppIntent Swift files.
- **Calling reloadAllTimelines() without ModelContext.save():** Writes to `ModelContext` are not persisted until `context.save()` is explicitly called (SwiftData's autosave happens in SwiftUI environment, but not in AppIntent's perform()). Must call `try? context.save()` before reload.
- **Using IntentConfiguration (legacy):** iOS 16 and earlier used SiriKit INIntents. iOS 17+ uses AppIntentConfiguration. Never use `IntentConfiguration` or `INExtensionPrincipalClassName` in new code.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Widget picker UI | Custom in-app habit assignment flow | AppIntentConfiguration + WidgetConfigurationIntent | iOS provides the picker in widget edit mode for free; custom UI adds friction |
| Habit data refresh scheduling | Custom refresh timer / UserDefaults polling | WidgetCenter.shared.reloadAllTimelines() | System handles deferral and batching; manual polling drains battery and doesn't work across processes |
| Widget entry animation | Animate within widget view | Don't — WidgetKit renders static snapshots | Animations in widget entry views are ignored; the system transitions between snapshots |
| App Group file lock | Custom file locking for shared SQLite | SharedModelContainer.container (SwiftData handles SQLite WAL mode) | SQLite WAL mode allows simultaneous reads from app + extension without locks |
| URL parsing boilerplate | Custom URL parser in onOpenURL | `URLComponents` from Foundation | Built-in, handles query params, nil-safe |

**Key insight:** Every custom solution in WidgetKit adds more attack surface for the platform's tight constraints. Use the APIs as designed and trust the system.

---

## Common Pitfalls

### Pitfall 1: Widget Refresh NOT Immediate on All Widgets After AppIntent

**What goes wrong:** Developer expects `WidgetCenter.shared.reloadAllTimelines()` in `perform()` to immediately refresh every widget instance on screen. On real devices, some widgets update slowly or not at all.

**Why it happens:** `reloadAllTimelines()` is a *suggestion* to the system. The OS batches and defers timeline reloads based on battery state and backgrounding constraints. The only *guaranteed* immediate refresh is for the specific widget the user just interacted with (the system grants one free timeline reload when `perform()` returns).

**How to avoid:** Do not design UX that requires multi-widget simultaneous refresh. Accept that the interacted widget updates immediately; other widgets update within seconds to minutes. For WID-05, this is satisfied because the *interacted* widget updates immediately.

**Warning signs:** "Widget doesn't update" bug reports that only repro on real device, not Simulator.

### Pitfall 2: SwiftData In-Memory State Mismatch Between App and Widget

**What goes wrong:** The widget writes a log entry via AppIntent. When the main app is next foregrounded, `@Query` in `TodayView` doesn't see the new data immediately.

**Why it happens:** The main app's `ModelContext` (in-memory) does not receive change notifications from another process's writes. The SQLite file is updated, but the in-memory cache is stale until the context is reset or the app restarts.

**How to avoid (WID-05 requirement):** In `TodayView` (or `TabRootView`), observe `scenePhase`. When transitioning from `.background` to `.active`, call `WidgetCenter.shared.reloadAllTimelines()` AND reset/refetch the model context. Alternatively, use `.onChange(of: scenePhase)` to trigger an explicit `@Query` invalidation. The `@Query` in `TodayView` will automatically refetch if the underlying store changes and the context is still live — but only after the in-memory state is refreshed.

**Warning signs:** Today view shows stale data after returning from home screen where a widget interaction occurred.

### Pitfall 3: AppIntent Target Membership Missing

**What goes wrong:** Widget buttons appear but do nothing, or the app crashes when attempting to invoke the intent from Shortcuts.

**Why it happens:** Xcode requires AppIntent swift files to be in the target membership of BOTH the main app AND the widget extension. If only in the widget target, the system cannot discover the intents for the app-level integration. If only in the app target, the widget extension cannot compile.

**How to avoid:** In Xcode's File Inspector, for every AppIntent file, check that both `HabitX` (app) and `HabitXWidget` (extension) are checked under Target Membership.

**Warning signs:** Build succeeds but tapping widget buttons has no effect on physical device. Or Shortcuts app doesn't show the actions.

### Pitfall 4: `context.save()` Not Called in AppIntent perform()

**What goes wrong:** Widget appears to update (the interacted widget reloads), but on next app launch or widget reload, the logged data is missing.

**Why it happens:** `ModelContext` in AppIntents does not run in a SwiftUI view environment, so SwiftData's automatic save-on-change behavior is not triggered. `context.save()` must be called explicitly.

**How to avoid:** Always call `try? context.save()` before returning `.result()` from `perform()`.

**Warning signs:** Log entries visible immediately in widget but gone after app kill/relaunch.

### Pitfall 5: Swift 6 Concurrency — TimelineProvider and MainActor

**What goes wrong:** Build errors like "Call to main actor-isolated function in a synchronous nonisolated context" when accessing `SharedModelContainer.container.mainContext` from `getTimeline`.

**Why it happens:** Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`) requires explicit actor annotation at every async boundary. `ModelContext.mainContext` is `@MainActor`-isolated.

**How to avoid:** Mark fetch helper functions `@MainActor`. For callback-based `TimelineProvider`, wrap calls in `Task { @MainActor in ... }`. For async `AppIntentTimelineProvider`, mark the `timeline(for:in:)` method or helpers as `@MainActor` and call them with `await`.

**Warning signs:** Build errors in widget target only, with messages about non-sendable types or MainActor isolation.

### Pitfall 6: Duplicate @main Entry Point in WidgetBundle

**What goes wrong:** Build error: "Attribute '@main' can only apply to one type in a module."

**Why it happens:** `HabitXWidgetBundle` is already `@main`. When a second `Widget` struct is added and someone adds `@main` to it or to the bundle file again.

**How to avoid:** Only `HabitXWidgetBundle` carries `@main`. Both widget structs are listed in the bundle body, not annotated individually.

### Pitfall 7: Hardcoded `kind` String Changes

**What goes wrong:** Updating a widget's `kind` string (e.g., from `"HabitXWidget"` to `"HabitSmallWidget"`) causes all existing user widget placements to disappear and reset to unconfigured.

**Why it happens:** iOS uses the `kind` string as the widget's persistent identity. A change is treated as a new, unrelated widget.

**How to avoid:** Choose `kind` strings once and never change them. Use distinct strings for the small (`"HabitSmallWidget"`) and medium (`"HabitMediumWidget"`) types from the start of Phase 3.

---

## Code Examples

### Full AppIntentConfiguration Widget Definition

```swift
// Source: Apple Developer Documentation (AppIntentConfiguration)
struct HabitSmallWidget: Widget {
    let kind = "HabitSmallWidget"  // stable — never change

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HabitWidgetIntent.self,
            provider: SmallWidgetProvider()
        ) { entry in
            SmallWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habit")
        .description("Track a single habit from your home screen.")
        .supportedFamilies([.systemSmall])
    }
}
```

### Button(intent:) in Widget View

```swift
// Source: appmakers.dev (verified pattern)
// In MediumWidgetEntryView row for a count habit:
Button(intent: {
    var intent = IncrementCountHabitIntent()
    intent.habitId = snapshot.id.uuidString
    return intent
}()) {
    Image(systemName: "plus.circle.fill")
        .foregroundStyle(Color.appAccent)
}
.buttonStyle(.plain)
```

### widgetURL for Input Habit (Small Widget)

```swift
// In SmallWidgetEntryView, when habitType == .input:
SmallWidgetContent(snapshot: snapshot)
    .widgetURL(URL(string: "habitx://log?id=\(snapshot.id.uuidString)")!)
```

### onOpenURL Handler in HabitXApp.swift

```swift
// In HabitXApp.swift body:
WindowGroup {
    TabRootView(deepLinkHabitId: $deepLinkHabitId)
        .onOpenURL { url in
            guard url.scheme == "habitx",
                  url.host == "log",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
                  let uuid = UUID(uuidString: idString)
            else { return }
            deepLinkHabitId = uuid
        }
}
.modelContainer(SharedModelContainer.container)
```

### FetchDescriptor in getTimeline (no @Query)

```swift
// Source: nicoladefilippo.com (verified pattern)
@MainActor
private func fetchAllHabitSnapshots() -> [HabitSnapshot] {
    let context = SharedModelContainer.container.mainContext
    let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
        sortBy: [SortDescriptor(\.sortOrder)]
    )
    let habits = (try? context.fetch(descriptor)) ?? []
    return habits.map { HabitSnapshot(habit: $0) }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `IntentConfiguration` + SiriKit `.intentdefinition` file | `AppIntentConfiguration` + Swift `AppIntent` / `WidgetConfigurationIntent` | iOS 17 / WWDC23 | No Xcode .intentdefinition file needed; all in Swift code |
| `IntentTimelineProvider` (callback + completion) | `AppIntentTimelineProvider` (async/await) | iOS 17 | Methods are `async`; no callback wrangling |
| `TimelineProvider` completion handlers (concurrency issues) | Same `TimelineProvider` but completion handlers are now `@Sendable` in Xcode 16 SDK | Xcode 16 / Swift 6 | Eliminates Sendable warnings in widget targets |
| `SiriKit INIntent` subclasses | `AppIntent` protocol conformance | iOS 16+ (AppIntents), iOS 17 for widgets | Pure Swift, no Objective-C bridge, discoverable by system |
| `requestUpdate()` for post-action reload | `WidgetCenter.shared.reloadAllTimelines()` | iOS 16+ reloadAllTimelines is current API; `requestUpdate` is iOS 18+ | On iOS 17, only reloadAllTimelines is available |

**Deprecated/outdated:**
- `IntentConfiguration`: Do not use for new widgets. Legacy SiriKit widget configuration. Replaced by `AppIntentConfiguration`.
- `INExtensionPrincipalClassName` in Info.plist: SiriKit extension entry point — not needed for AppIntents-based widgets.
- `getSnapshot(in:context:completion:)` with non-`@Sendable` closure: Caused Swift 5.9 strict concurrency warnings; fixed in Xcode 16 SDK.

---

## Open Questions

1. **Deep-link state restoration in TabRootView**
   - What we know: `onOpenURL` fires reliably. `TabRootView` owns the tab selection state.
   - What's unclear: How to navigate to the Today tab AND present `NumberInputSheet` for the correct habit when the app is launched cold from a widget deep-link. Requires `@State` / `@Binding` wiring through `TabRootView`.
   - Recommendation: Add a `@State var deepLinkHabitId: UUID? = nil` to `HabitXApp`, pass as binding to `TabRootView`. When non-nil, switch to Today tab and show `NumberInputSheet` for that habit. Clear after presenting.

2. **`context.save()` throwing in AppIntent perform()**
   - What we know: The write pattern with `try? context.save()` silently swallows errors.
   - What's unclear: Whether the AppIntent framework surfaces save errors to the user/system in a useful way.
   - Recommendation: Use `try? context.save()` (silent) for this phase; the retry risk is low (write is simple). If needed, surface a `ReturnsValue` string error to the system in a future iteration.

3. **TodayView @Query stale data after widget interaction**
   - What we know: SwiftData in-memory state in main app does not auto-update from extension writes.
   - What's unclear: Whether `@Query` in `TodayView` auto-invalidates when the app returns to foreground (scenePhase change).
   - Recommendation: Add `.onChange(of: scenePhase) { _, new in if new == .active { /* no-op; @Query auto-refetches */ } }`. If stale data is observed on physical device testing, explicitly reset the model context or re-insert a fresh `@Query` via a view identity trick. Flag for WID-05 physical device verification.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16.3+ | Swift 6.1, iOS 18 SDK for AppIntentTimelineProvider signatures | Must be verified by developer | 16.3 (pinned in project) | None — required per CLAUDE.md |
| iOS 17+ Simulator or Device | Widget interactive testing | Simulator available | iOS 17+ | Physical device required for WID-02/WID-03 verification (per project STATE.md blocker) |
| App Groups provisioning | Shared SwiftData store | group.com.habitx.shared confirmed in entitlements | — | No fallback — required for widget data access |
| `habitx://` URL scheme | WID-04 input deep-link | NOT YET REGISTERED | — | Must add CFBundleURLTypes to main app Info.plist / project.yml |

**Missing dependencies with no fallback:**
- `habitx://` URL scheme must be registered in the main app target before deep-link testing. Add to `project.yml` under `HabitX` target's `info.plist` section.

**Missing dependencies with fallback:**
- Physical device: WID-02 and WID-03 interactive widget actions should be verified on a physical device (not just Simulator), per existing STATE.md blocker. Simulator can test layout and non-interactive flows.

---

## Validation Architecture

> nyquist_validation is explicitly set to false in .planning/config.json. Skipping this section.

---

## Sources

### Primary (HIGH confidence)
- [Apple Developer — AppIntentConfiguration](https://developer.apple.com/documentation/widgetkit/appintentconfiguration)
- [Apple Developer — AppIntentTimelineProvider](https://developer.apple.com/documentation/widgetkit/appintenttimelineprovider)
- [Apple Developer — WidgetConfigurationIntent](https://developer.apple.com/documentation/appintents/widgetconfigurationintent)
- [Apple Developer — WidgetCenter.reloadAllTimelines()](https://developer.apple.com/documentation/widgetkit/widgetcenter/reloadalltimelines())
- [Apple Developer — Linking to specific app scenes from widget](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity)
- CLAUDE.md — iOS 17+ constraints, AppIntents over SiriKit, AppIntentTimelineProvider requirement

### Secondary (MEDIUM confidence)
- [appmakers.dev — Configurable Widget with AppIntents and SwiftData](https://appmakers.dev/how-to-build-a-swiftui-widget-with-app-intents-and-swiftdata-configurable-widget/) — complete end-to-end pattern verified against Apple docs
- [Alexander Weiss — AppIntents for Widgets](https://alexanderweiss.dev/blog/2023-06-10-appintents-for-widgets) — async AppIntentTimelineProvider pattern, cross-referenced
- [Nicola De Filippo — Share SwiftData with a Widget](https://nicoladefilippo.com/share-swiftdata-with-a-widget/) — FetchDescriptor in TimelineProvider, @MainActor requirement
- [sarunw.com — Circular Progress Bar in SwiftUI](https://sarunw.com/posts/swiftui-circular-progress-bar/) — Circle().trim() ring pattern
- [Swift Forums — WidgetKit and sendability problem](https://forums.swift.org/t/widgetkit-and-sendability-problem/72915) — Xcode 16 SDK fixes @Sendable completion handlers in TimelineProvider

### Tertiary (LOW confidence — single source, unverified)
- [Apple Developer Forums thread 741691](https://developer.apple.com/forums/thread/741691) — one free guaranteed reload per widget interaction (matches WWDC session description but not in official written docs)
- [viralsfire.com — Fix @Model AppEntity conformance error](https://viralsfire.com/post/fix-error-when-make-swift-data-model-conform-to-app-entity) — recommends separate AppEntity struct, consistent with community consensus

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple system frameworks, no third-party dependencies
- Architecture patterns: HIGH — verified against appmakers.dev + Alexander Weiss (cross-referenced with Apple docs)
- SwiftData/timeline provider patterns: HIGH — verified in multiple community sources + official API docs
- Swift 6 concurrency notes: MEDIUM — Xcode 16 SDK fixes most issues; specific AppIntent @MainActor behavior confirmed by forum consensus but not in single official doc
- Widget refresh timing (one guaranteed reload): LOW/MEDIUM — widely reported in forums and consistent with WWDC session description; not in one official written statement

**Research date:** 2026-03-30
**Valid until:** 2026-06-30 (stable Apple APIs; reassess if iOS 19 / Xcode 17 ships before completion)
