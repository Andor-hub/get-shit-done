# Architecture Patterns

**Project:** HabitX 2.0 — Native iOS Habit Tracker with WidgetKit
**Researched:** 2026-03-27
**Confidence:** HIGH (Apple developer docs, WWDC sessions, verified community sources)

---

## Recommended Architecture

**MVVM with @Observable (iOS 17 style), SwiftData persistence, App Groups for widget data sharing.**

TCA was evaluated and rejected for this project: it introduces substantial boilerplate overhead that is disproportionate to a single-user, local-only app of this scope. The vanilla MV (no view model) pattern was also evaluated and rejected — it does not separate concerns well enough for the widget boundary, where a clean data layer is non-negotiable. MVVM with the `@Observable` macro (iOS 17+) hits the sweet spot: testable, maintainable, minimal ceremony.

---

## Xcode Project Structure

### Targets

| Target | Type | Bundle ID Pattern |
|--------|------|-------------------|
| HabitX | iOS App | `com.yourname.HabitX` |
| HabitXWidget | Widget Extension | `com.yourname.HabitX.Widget` |

Both targets must share the same **App Group** container. This is the only mechanism that allows SwiftData's SQLite store to be accessed by both the main app process and the widget extension process.

### Required Capabilities (per target)

| Capability | HabitX App | HabitXWidget |
|------------|-----------|--------------|
| App Groups | YES — `group.com.yourname.HabitX` | YES — same identifier |
| Push Notifications | YES | NO |
| Background App Refresh | Optional | NO |

### Entitlements

Both targets need `com.apple.security.application-groups` with the same group identifier. This is set in each target's `.entitlements` file and must be provisioned in the Apple Developer portal.

### Source File Membership

SwiftData model files (e.g., `Habit.swift`, `HabitLog.swift`) must be added to **both** targets. In Xcode's File Inspector, check both the app target and the widget target in the "Target Membership" section.

---

## Component Boundaries

```
┌─────────────────────────────────────────────────────────────────┐
│  HabitX App Target                                              │
│                                                                 │
│  ┌─────────────┐   ┌──────────────────┐   ┌─────────────────┐  │
│  │  SwiftUI    │   │  ViewModels      │   │  Notification   │  │
│  │  Views      │◄──│  (@Observable)   │   │  Manager        │  │
│  │             │   │                  │   │  (UNUserNotif.) │  │
│  │  TodayView  │   │  TodayVM         │   │                 │  │
│  │  HistoryView│   │  HabitDetailVM   │   └────────┬────────┘  │
│  │  StatsView  │   │  StatsVM         │            │           │
│  └──────┬──────┘   └────────┬─────────┘            │           │
│         │                   │                      │           │
│         └───────────────────┼──────────────────────┘           │
│                             │                                   │
│                    ┌────────▼─────────────────────────┐        │
│                    │  SwiftData Layer                  │        │
│                    │  ModelContainer (shared via        │        │
│                    │  App Group group container)        │        │
│                    │                                   │        │
│                    │  @Model Habit                     │        │
│                    │  @Model HabitLog                  │        │
│                    └────────────────┬──────────────────┘        │
└─────────────────────────────────────┼───────────────────────────┘
                                      │  (App Group SQLite store)
                    ┌─────────────────▼──────────────────────────┐
                    │  Shared App Group Container                 │
                    │  ~/AppGroup/com.yourname.HabitX/default.store│
                    └─────────────────┬──────────────────────────┘
                                      │
┌─────────────────────────────────────▼───────────────────────────┐
│  HabitXWidget Extension Target                                  │
│                                                                 │
│  ┌───────────────────┐   ┌──────────────────────────────────┐   │
│  │  Widget Views     │   │  HabitTimelineProvider           │   │
│  │  (SwiftUI)        │   │  (TimelineProvider)              │   │
│  │                   │◄──│                                  │   │
│  │  HabitWidgetEntry │   │  placeholder(in:)                │   │
│  │  View             │   │  getSnapshot(in:completion:)     │   │
│  │                   │   │  getTimeline(in:completion:)     │   │
│  └───────────────────┘   └──────────────────────────────────┘   │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  AppIntents (interactive widget actions)                  │  │
│  │                                                           │  │
│  │  ToggleHabitIntent  (boolean habits)                      │  │
│  │  IncrementHabitIntent  (count habits)                     │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| SwiftUI Views (app) | Render UI, forward user actions | ViewModels (read state, call methods) |
| ViewModels (@Observable) | Business logic, data transformation, coordinate persistence | SwiftData ModelContext, NotificationManager |
| SwiftData Models (@Model) | Persistent data definition, schema | Both targets via App Group container |
| NotificationManager | Schedule/cancel per-habit UNNotificationRequests | UNUserNotificationCenter, called by ViewModels |
| HabitTimelineProvider | Supply timeline entries to WidgetKit | SwiftData ModelContext (read-only via App Group) |
| Widget Views | Render widget entry state | HabitTimelineProvider entries |
| AppIntents | Handle widget button taps, write to SwiftData, trigger reload | SwiftData ModelContext (write), WidgetCenter |

---

## Data Models

### Habit

```swift
@Model
class Habit {
    var id: UUID
    var name: String
    var habitType: HabitType  // enum: boolean | count | input
    var dailyTarget: Double   // 1.0 for boolean, N for count/input
    var unit: String?         // "cups", "grams", etc.
    var reminderTime: Date?   // nil = no reminder
    var createdAt: Date
    var sortOrder: Int

    // Relationship
    @Relationship(deleteRule: .cascade)
    var logs: [HabitLog] = []
}

enum HabitType: String, Codable {
    case boolean
    case count
    case input
}
```

### HabitLog

```swift
@Model
class HabitLog {
    var id: UUID
    var date: Date            // normalized to start-of-day
    var value: Double         // 1.0 for boolean done, N for count/input
    var loggedAt: Date        // exact timestamp
    var habit: Habit?
}
```

**Design decision:** Store `value` as `Double` on every log entry. This means:
- Boolean: a log entry with `value: 1.0` = done, absence of entry = not done
- Count: entries accumulate; query sums `value` for the day
- Input: same as count

This avoids a polymorphic type design and keeps the query layer simple.

---

## Data Flow

### Main App — User Logs a Habit

```
User taps "+" in TodayView
  → TodayViewModel.logHabit(habit:value:)
    → ModelContext.insert(HabitLog(...))
    → ModelContext.save()
    → WidgetCenter.shared.reloadTimelines(ofKind: habit.widgetKind)
```

The WidgetCenter reload call after a save ensures the widget reflects new data when the app is open and the user just logged. This is reliable when called from the foreground app process.

### Widget — User Taps Interactive Button

```
User taps toggle/increment button on home screen widget
  → WidgetKit calls AppIntent.perform()
    → AppIntent creates ModelContext from SharedModelContainer
    → AppIntent fetches Habit + today's logs from SwiftData
    → AppIntent mutates / inserts HabitLog
    → ModelContext.save()
    → WidgetCenter.shared.reloadAllTimelines()
    → AppIntent returns .result()
  → WidgetKit calls TimelineProvider.getTimeline()
    → Provider queries SwiftData for updated data
    → Returns new TimelineEntry
  → Widget view re-renders with new entry
```

Note: The `.result()` return from `perform()` is what triggers WidgetKit to solicit a new timeline. `reloadAllTimelines()` in the perform method is belt-and-suspenders; the automatic re-query after `.result()` is the primary refresh mechanism.

### Widget — Input Habit (Protein) — Deep Link

Input habits cannot accept text in a widget (iOS platform limitation — no text fields in widget views). The pattern is:

```
User taps protein widget
  → Widget Button with AppIntent or URL scheme opens app
    → App navigates to input logging sheet for that habit
    → User enters value, confirms
    → TodayViewModel saves log
    → WidgetCenter.shared.reloadTimelines(ofKind:)
```

Use a URL scheme (`habitx://log?habitId=<UUID>`) or `openAppIntent` for deep-linking into the specific habit's log screen.

### Widget Timeline Refresh Strategy

Habit trackers have a predictable daily reset at midnight. Use this:

```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
    let entry = HabitEntry(date: .now, habits: fetchCurrentHabits())

    // Schedule the next refresh at midnight (day boundary reset)
    let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
    let timeline = Timeline(entries: [entry], policy: .after(midnight))
    completion(timeline)
}
```

Supplement with `WidgetCenter.shared.reloadTimelines()` calls from the app when:
- User logs a habit in the app
- App comes to foreground (`onChange(of: scenePhase)`)
- User edits or deletes a habit

Do not use `.atEnd` for a habit tracker — you don't need updates every 15 minutes when nothing changed. Midnight refresh + explicit invalidation from the app is the right balance within the ~40-70 refresh daily budget.

---

## Shared ModelContainer Pattern

This is the most critical implementation detail. Both targets must point to the same SQLite store via App Groups.

```swift
// SharedModelContainer.swift — added to BOTH app and widget targets

struct SharedModelContainer {
    static let container: ModelContainer = {
        let schema = Schema([Habit.self, HabitLog.self])
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.com.yourname.HabitX")
        )
        return try! ModelContainer(for: schema, configurations: config)
    }()
}
```

**Main App** — attach at the root:
```swift
@main
struct HabitXApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SharedModelContainer.container)
    }
}
```

**Widget Extension** — attach to widget configuration:
```swift
struct HabitXWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(...) { entry in
            HabitWidgetEntryView(entry: entry)
                .modelContainer(SharedModelContainer.container)
        }
    }
}
```

**AppIntents** — create a ModelContext directly:
```swift
struct ToggleHabitIntent: AppIntent {
    @Parameter var habitId: String

    func perform() async throws -> some IntentResult {
        let context = ModelContext(SharedModelContainer.container)
        // fetch, mutate, save
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

---

## WidgetKit Architecture Detail

### TimelineEntry

```swift
struct HabitEntry: TimelineEntry {
    let date: Date
    let habit: HabitSnapshot   // value-type snapshot, NOT a live @Model
    let todayProgress: Double
    let dailyTarget: Double
}

struct HabitSnapshot {
    let id: UUID
    let name: String
    let habitType: HabitType
    let unit: String?
}
```

Use value-type snapshots in TimelineEntry, not live SwiftData model references. The widget rendering process may occur after the model context has been deallocated.

### Widget Family Support

Each habit gets its own widget. Support these families initially:

| Family | Content |
|--------|---------|
| `.systemSmall` | Habit name, progress ring, tap action |
| `.systemMedium` | Name, progress bar, last logged time |

Lock down to these two families for v1. Larger families complicate layout without adding habit-tracking value.

### Widget Configuration Type

- Boolean and count habits: `AppIntentConfiguration` — widget is interactive, no user configuration needed
- Input habits: `StaticConfiguration` — widget is display-only, tap opens app

---

## Notification Architecture

```
NotificationManager (singleton service)
  ├── scheduleReminder(for habit: Habit)
  │     → UNMutableNotificationContent (title, body)
  │     → UNCalendarNotificationTrigger (daily at habit.reminderTime)
  │     → UNNotificationRequest(identifier: habit.id.uuidString, ...)
  │     → UNUserNotificationCenter.add(request)
  │
  ├── cancelReminder(for habit: Habit)
  │     → UNUserNotificationCenter.removePendingNotificationRequests([habit.id.uuidString])
  │
  └── rescheduleAllReminders(habits: [Habit])
        → cancel all → schedule all with current reminder times
```

Use `habit.id.uuidString` as the notification identifier. This allows precise cancellation when a habit is edited or deleted without clearing all notifications. The daily trigger fires at the same time every day until explicitly removed.

Request notification authorization at first launch with `.alert + .sound`. Do not request authorization until the user adds their first habit with a reminder enabled.

---

## Scalability Considerations

| Concern | At v1 (local only) | At v2 (backend/social) |
|---------|-------------------|----------------------|
| Persistence | SwiftData + App Groups | Add CloudKit sync via ModelConfiguration or custom backend |
| Auth | None | Sign In with Apple; add to app target only |
| Widget data | App Group SQLite | Same — widget reads from local store; sync happens in background |
| Model versioning | SwiftData migrations | Plan schema versions early; migration is painful retroactively |

**CloudKit migration path:** SwiftData supports CloudKit sync by adding `.cloudKitDatabase(.private("iCloud.com.yourname.HabitX"))` to the `ModelConfiguration`. This requires iCloud capability added to the main app target. The widget extension does NOT get CloudKit — it reads from the local replica. This path is non-breaking if the App Group store URL is established from the start.

---

## Suggested Build Order

Components have hard dependencies that dictate the correct build order. Building out of order causes rework.

```
1. Xcode Project Setup
   - Create app target + widget extension target
   - Configure App Groups (both targets)
   - Shared entitlements, bundle IDs, provisioning
   ↓
2. SwiftData Models (Habit, HabitLog)
   - Add to BOTH target memberships
   - SharedModelContainer singleton
   - Verify App Group store path
   ↓
3. Main App CRUD — no widgets yet
   - Add/edit/delete habits
   - Log entries (all three types)
   - TodayView, basic ViewModels
   ↓
4. Widget Display (read-only first)
   - TimelineProvider reads from App Group store
   - Widget views show progress
   - StaticConfiguration widgets
   - Verify data flows from app → widget
   ↓
5. Widget Interactivity (AppIntents)
   - ToggleHabitIntent (boolean)
   - IncrementHabitIntent (count)
   - AppIntentConfiguration widgets
   - Input habit deep-link tap
   ↓
6. Notifications
   - NotificationManager service
   - Per-habit scheduling
   - Edit/delete cascade (cancel + reschedule)
   ↓
7. Stats + History Views
   - StatsViewModel with streak/completion math
   - HistoryView with per-habit log browsing
   - No new architecture — reads from existing store
```

**Rationale for this order:**
- Steps 1-2 are pure infrastructure. Nothing else can be built without them.
- Step 3 before widgets: establish data integrity in the main app before the widget extension reads from it. Debugging a broken data layer through a widget adds unnecessary indirection.
- Step 4 (display) before Step 5 (interactive): read-only widgets are simpler to debug. Confirm the App Group store sharing works before introducing AppIntent write-backs.
- Notifications (Step 6) are independent of widget interactivity — they can slide in any time after the model layer exists, but do not block widget development.
- Stats/History (Step 7) are pure consumers of existing data. No new persistence work required.

---

## Anti-Patterns to Avoid

### 1. Storing Model References in TimelineEntry
**What goes wrong:** Passing a live `@Model` object into a `TimelineEntry`. The widget rendering process is separate from the model context lifecycle.
**Instead:** Serialize to a value-type snapshot struct before returning from `getTimeline`.

### 2. Separate SQLite Stores for App and Widget
**What goes wrong:** Creating a `ModelContainer` without the `groupContainer` configuration in one or both targets. The widget reads stale or empty data.
**Instead:** Use `SharedModelContainer` (the singleton pattern above) in every location — app root, widget configuration, and AppIntents.

### 3. Calling reloadAllTimelines() as the Only Refresh Mechanism
**What goes wrong:** `reloadAllTimelines()` from the main app is unreliable for immediate widget refresh. Timeline reload after `AppIntent.perform()` returns `.result()` is the authoritative mechanism.
**Instead:** Rely on the post-`.result()` automatic re-query as primary; call `reloadAllTimelines()` from the app as a secondary signal, not the only one.

### 4. Per-Widget ModelContainer Instantiation
**What goes wrong:** Creating a new `ModelContainer` inside the TimelineProvider initializer as a computed property. Multiple instantiations can cause SQLite lock contention.
**Instead:** Use the static singleton `SharedModelContainer.container` everywhere.

### 5. Requesting Notification Permission at Launch
**What goes wrong:** Users see the permission prompt before they understand the value, leading to denial. iOS does not allow re-prompting after denial.
**Instead:** Request permission contextually — when the user first enables a reminder on a habit. Gate the scheduling call with a prior authorization check.

---

## Sources

- [WidgetKit Documentation — Apple Developer](https://developer.apple.com/documentation/widgetkit) (HIGH confidence)
- [TimelineProvider — Apple Developer](https://developer.apple.com/documentation/widgetkit/timelineprovider) (HIGH confidence)
- [How to access a SwiftData container from widgets — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-access-a-swiftdata-container-from-widgets) (HIGH confidence)
- [How to Build a Configurable SwiftUI Widget with App Intents and SwiftData — AppMakers.DEV](https://appmakers.dev/how-to-build-a-swiftui-widget-with-app-intents-and-swiftdata-configurable-widget/) (HIGH confidence — verified against Apple docs patterns)
- [SwiftData with Widgets in SwiftUI — Rishabh Sharma / Medium](https://medium.com/@rishixcode/swiftdata-with-widgets-in-swiftui-0aab327a35d8) (MEDIUM confidence)
- [Interactive Widget reload timeline on interaction — Apple Developer Forums](https://developer.apple.com/forums/thread/736323) (HIGH confidence)
- [Interactive Widgets With SwiftUI — Kodeco](https://www.kodeco.com/43771410-interactive-widgets-with-swiftui) (MEDIUM confidence)
- [Explore enhancements to App Intents — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10103/) (HIGH confidence)
- [Modern MVVM in SwiftUI 2025 — Medium](https://medium.com/@minalkewat/modern-mvvm-in-swiftui-2025-the-clean-architecture-youve-been-waiting-for-72a7d576648e) (MEDIUM confidence)
- [Keeping a widget up to date — Apple Developer](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) (HIGH confidence)
- [UNUserNotificationCenter — Apple Developer](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) (HIGH confidence)
