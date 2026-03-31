# Phase 2: Core App - Research

**Researched:** 2026-03-29
**Domain:** SwiftUI app architecture — Today view, habit management, logging interactions, History, Stats
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Display habits as **cards** (rounded, with breathing room) — not compact rows
- **D-02:** Each card shows **name + progress only** (e.g. "Water — 3/8 cups", "Meditate — Done"). No streak inline on the card.
- **D-03:** Empty state is a single **"Add habit" button**. When tapped, a picker opens that offers: (a) premade habits (Protein, Water) with pre-configured defaults that the user can adjust, or (b) blank habit from scratch with full configuration. No other content in the empty state.
- **D-04:** **Boolean habits** — tap anywhere on the card toggles done/undone. No separate button needed.
- **D-05:** **Count habits (e.g. Water)** — a `+` button on the card increments by 1 each tap. Fast, one-handed, matches widget.
- **D-06:** **Input habits (e.g. Protein)** — a `+` button on the card opens a number input sheet for manual value entry. User types the value and confirms. This matches the widget deep-link behavior in Phase 3.
- **D-07:** The logging control (tap / `+` button) is the primary interaction. No need for a separate habit detail screen to log — logging happens directly from the Today card.
- **D-08:** **Tab bar** with three top-level tabs: Today, History, Stats.
- **D-09:** Habit management (add/edit/delete/reorder) is accessed via **Edit mode on the Today view** — an "Edit" button in the navbar puts the habit list into iOS-standard edit mode (drag handles for reorder, swipe-to-delete or delete buttons, tap habit to open edit sheet).
- **D-10:** History tab and Stats tab are **per-habit** — each tab shows a list of habits, and tapping one drills into that habit's history log or stats detail.
- **D-11:** App respects **iOS system appearance** (dark/light mode) — does not force either. Uses SwiftUI's standard adaptive colors so it looks correct in both modes.
- **D-12:** **Single accent color** across all habits — one brand accent (exact color is Claude's discretion, but should be calm and health-appropriate, e.g. a blue or teal). Used for progress fills, active states, and primary buttons.

### Claude's Discretion

- Exact accent color (blue, teal, green — pick what looks best in both dark and light mode)
- Stats detail layout — how streak, best streak, and 30-day rate are visually arranged (numbers + labels, simple chart, or both)
- History detail layout — scrollable list of past dates with logged values (calendar grid vs. chronological list)
- Loading/transition animations — keep lightweight, no elaborate animations
- Add habit sheet vs. full-screen cover — Claude picks what fits best for the configuration flow
- Confirmation dialog copy for habit deletion

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within Phase 2 scope.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HAB-01 | User can create a habit with name, type, and daily target | Add habit sheet with HabitType picker and numeric target field |
| HAB-02 | User can choose from default habits (Protein, Water) with pre-filled recommended targets | Template picker sheet with premade Habit structs |
| HAB-03 | User can edit a habit's name, type, target, and notification time | Edit sheet reusing the same form as creation; `@Bindable` on the Habit model |
| HAB-04 | User can delete a habit (with confirmation) | `.confirmationDialog` + `modelContext.delete()` |
| HAB-05 | User can reorder habits in the Today view | `onMove` + updating `sortOrder` on moved items |
| LOG-01 | User can mark a boolean habit as done or undone from the Today view | Tap-on-card gesture → upsert/delete HabitLog for today |
| LOG-02 | User can increment a count habit from the Today view | `+` button → upsert HabitLog adding 1 to value |
| LOG-03 | User can log a numerical value for an input habit from the Today view | `+` button → sheet with `TextField(.numberPad)` → upsert HabitLog |
| LOG-04 | All habit logs reset at midnight for the new day (timezone-aware) | `Calendar.current.startOfDay(for: Date())` as the log date boundary |
| TODAY-01 | User sees all their habits in a single scrollable Today view | `@Query` sorted by `sortOrder` in a `ScrollView + LazyVStack` |
| TODAY-02 | Each habit shows current progress vs. daily target | Compute today's aggregate from `habit.logs` filtered to today |
| TODAY-03 | Completed habits are visually distinct from incomplete habits | Accent fill + checkmark or desaturated state when value >= target |
| TODAY-04 | User can log any habit type directly from the Today view | Unified card with type-dispatched interaction handler |
| HIST-01 | User can view a per-habit log of past completions by date | Per-habit history view with date-sorted list of HabitLog entries |
| HIST-02 | History shows the logged value/count/completion for each past day | Display each HabitLog's `value` formatted per habit type |
| HIST-03 | User can navigate back at least 90 days of history | Generate 90-day date range; show empty state for days with no log |
| STAT-01 | Each habit shows a current streak (consecutive days completed) | Algorithm: walk backward from today, count consecutive days with a completed log |
| STAT-02 | Each habit shows a best-ever streak | Algorithm: scan all log dates, find longest consecutive run |
| STAT-03 | Each habit shows a 30-day completion rate (percentage) | Count completed days in last 30 days / 30 |
| STAT-04 | Missed days are displayed as neutral data (not punished visually) | Use neutral secondary colors for missed days, no red/warning styling |

</phase_requirements>

---

## Summary

Phase 2 builds the complete main app UI on top of the Phase 1 infrastructure (SwiftData schema, shared container, App Groups). The stack is fully decided: SwiftUI with `@Observable` ViewModels, `@Query` for live data in views, and `ModelContext` for writes. The three habit types require three distinct logging interactions dispatched from a single card component.

The most architecturally important decision is **where @Query lives**. Because `@Query` requires SwiftUI's environment, it cannot live inside `@Observable` ViewModels. The correct pattern is to place `@Query` directly in views (or thin subviews), let models themselves be `@Observable` (SwiftData `@Model` auto-conforms), and push write logic to a lightweight service or directly to `modelContext`. This avoids the MVVM/SwiftData impedance mismatch while keeping views lean.

Streak and stats calculations must be computed from raw `HabitLog` arrays — there is no built-in SwiftData aggregation. These are pure Swift algorithms operating on in-memory arrays after an initial `@Query` fetch, and they are fast enough for the data volumes expected. The midnight reset requirement is solved correctly with `Calendar.current.startOfDay(for: Date())` — the user's local timezone is respected automatically since `Calendar.current` uses the device timezone.

**Primary recommendation:** Use `@Query(sort: \.sortOrder)` directly in TodayView to drive the habit list. For filtered queries (today's logs, per-habit history), use the `init(filter:)` injection pattern in child views. Keep stats computation as pure functions on `[HabitLog]` arrays.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ API surface | All UI: Today, History, Stats, Add/Edit sheets | Mandatory per project constraints; WidgetKit requires SwiftUI; `@Observable` requires iOS 17 |
| SwiftData | iOS 17+ | Persistence — `@Query` in views, `ModelContext` for writes | Established in Phase 1; `@Model` auto-`@Observable`; `@Query` provides live UI updates |
| Observation (`@Observable`) | iOS 17+ | ViewModel layer for non-model state (sheet presentation, form fields) | Replaces `ObservableObject`; finer re-render granularity; less boilerplate |
| Swift Charts | iOS 16+ (bundled) | Stats view — 30-day bar chart of completions | Zero dependency, built into SwiftUI, sufficient for simple bar/line charts |
| Swift Testing | Xcode 16 / Swift 6 | Unit tests for streak algorithm, log filtering, date boundary logic | Modern Apple test framework; parameterized tests ideal for date-edge-case coverage |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation `Calendar` | Built-in | All date math — startOfDay, isDateInToday, date arithmetic | Every date comparison in logs and streak calculation |
| `@Bindable` | iOS 17+ | Bind directly to `@Observable` / `@Model` objects in edit forms | Use when a child view needs to mutate properties on an existing Habit model |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@Query` directly in views | FetchDescriptor in ViewModel | ViewModel approach loses live `@Query` reactivity; use only when dynamic predicate logic cannot be expressed in a child view init |
| Custom streak implementation | Third-party date library (SwiftDate) | SwiftDate adds a dependency; Foundation `Calendar` is fully sufficient for streak and date comparison logic in this app |
| Swift Charts | Custom `GeometryReader` bars | Hand-rolled bars are error-prone and lack accessibility; Swift Charts handles this in ~5 lines |

**Installation:** No additional packages required. All libraries are Apple frameworks included with Xcode 16.3.

---

## Architecture Patterns

### Recommended Project Structure

```
HabitX/HabitX/
├── HabitXApp.swift              # App entry point (no changes needed — .modelContainer already wired)
├── ContentView.swift            # Replace with TabRootView (root tab bar)
├── Models/
│   └── Schema/
│       ├── HabitSchemaV1.swift  # Existing @Model definitions — DO NOT MODIFY
│       ├── HabitMigrationPlan.swift  # Existing migration plan — DO NOT MODIFY
│   └── SharedModelContainer.swift   # Existing container — DO NOT MODIFY
├── Features/
│   ├── Today/
│   │   ├── TodayView.swift          # @Query(sort: \.sortOrder) — tab root
│   │   ├── HabitCardView.swift      # Single card for one habit; type-dispatched logging
│   │   ├── LogInputSheet.swift      # Number input sheet for input-type habits
│   │   └── TodayViewModel.swift     # @Observable — edit mode state, sheet triggers
│   ├── HabitForm/
│   │   ├── HabitTemplatePickerView.swift  # "Choose template or blank" picker
│   │   └── HabitFormView.swift      # Add/edit form (reused for both add and edit)
│   ├── History/
│   │   ├── HistoryListView.swift    # Habit list for History tab
│   │   └── HabitHistoryView.swift   # Per-habit 90-day log list
│   ├── Stats/
│   │   ├── StatsListView.swift      # Habit list for Stats tab
│   │   └── HabitStatsView.swift     # Per-habit streak + rate detail
│   └── Root/
│       └── TabRootView.swift        # TabView with 3 tabs
├── Services/
│   └── HabitLogService.swift    # Write logic: upsert/delete logs, update sortOrder
└── Utilities/
    └── StatsCalculator.swift    # Pure functions: currentStreak, bestStreak, completionRate
```

### Pattern 1: @Query in View (Primary Data Loading)

**What:** Place `@Query` directly in views to get live SwiftData updates. Do not put @Query in ViewModels.

**When to use:** Any view that displays a list of habits or logs that must stay in sync with the store.

```swift
// TodayView.swift
struct TodayView: View {
    @Query(sort: \HabitSchemaV1.Habit.sortOrder) private var habits: [HabitSchemaV1.Habit]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TodayViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(habits) { habit in
                        HabitCardView(habit: habit)
                    }
                    .onMove { indices, newOffset in
                        viewModel.moveHabits(habits, from: indices, to: newOffset, context: modelContext)
                    }
                    .onDelete { indices in
                        viewModel.deleteHabits(habits, at: indices, context: modelContext)
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                EditButton()
                Button("Add") { viewModel.showingAddHabit = true }
            }
        }
    }
}
```

### Pattern 2: @Query with Init Injection (Filtered Queries)

**What:** Pass filter values through a child view's `init()` so `@Query` can use a non-constant predicate.

**When to use:** Per-habit history view where the habitID is dynamic; any @Query that needs a runtime-determined predicate.

```swift
// HabitHistoryView.swift — receives habitID from parent
struct HabitHistoryView: View {
    @Query private var logs: [HabitSchemaV1.HabitLog]
    let habit: HabitSchemaV1.Habit

    init(habit: HabitSchemaV1.Habit) {
        self.habit = habit
        let habitID = habit.id
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        _logs = Query(
            filter: #Predicate<HabitSchemaV1.HabitLog> { log in
                log.habit?.id == habitID && log.date >= ninetyDaysAgo
            },
            sort: \HabitSchemaV1.HabitLog.date,
            order: .reverse
        )
    }

    var body: some View {
        List(logs) { log in
            // render log entry
        }
    }
}
```

### Pattern 3: Today's Log Computation

**What:** Determine today's logged value for a habit without a separate @Query — compute from the already-loaded `habit.logs` relationship.

**When to use:** HabitCardView progress display; logging action decisions (toggle vs. increment vs. set value).

```swift
// In HabitCardView or HabitLogService
func todayValue(for habit: HabitSchemaV1.Habit) -> Double {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
    return habit.logs
        .filter { $0.date >= startOfToday && $0.date < endOfToday }
        .reduce(0) { $0 + $1.value }
}

func isCompleted(habit: HabitSchemaV1.Habit) -> Bool {
    todayValue(for: habit) >= habit.dailyTarget
}
```

### Pattern 4: Log Upsert (Write Pattern)

**What:** For boolean habits, a HabitLog with value=1.0 means "done"; toggling deletes the log. For count/input habits, accumulate values in a single log per day (or append and sum — design decision: single log per day is simpler).

**Recommendation:** Use **one HabitLog per day per habit** for count and input types, updating `value` in place. For boolean, presence of a log with value=1.0 means done.

```swift
// HabitLogService.swift
func toggleBoolean(habit: Habit, context: ModelContext) {
    let today = Calendar.current.startOfDay(for: Date())
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    if let existing = habit.logs.first(where: { $0.date >= today && $0.date < tomorrow }) {
        context.delete(existing)
    } else {
        let log = HabitLog()
        log.date = today
        log.value = 1.0
        log.habit = habit
        context.insert(log)
    }
}

func incrementCount(habit: Habit, context: ModelContext) {
    let today = Calendar.current.startOfDay(for: Date())
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    if let existing = habit.logs.first(where: { $0.date >= today && $0.date < tomorrow }) {
        existing.value += 1.0
    } else {
        let log = HabitLog()
        log.date = today
        log.value = 1.0
        log.habit = habit
        context.insert(log)
    }
}
```

### Pattern 5: Streak Calculation (Pure Function)

**What:** Walk the habit's log dates backward from today. Count consecutive calendar days that have a completed log.

```swift
// StatsCalculator.swift
func currentStreak(for habit: Habit) -> Int {
    let calendar = Calendar.current
    let completedDays = Set(
        habit.logs
            .filter { $0.value >= habit.dailyTarget }
            .map { calendar.startOfDay(for: $0.date) }
    )
    var streak = 0
    var check = calendar.startOfDay(for: Date())
    while completedDays.contains(check) {
        streak += 1
        check = calendar.date(byAdding: .day, value: -1, to: check)!
    }
    return streak
}

func bestStreak(for habit: Habit) -> Int {
    let calendar = Calendar.current
    let sortedDays = habit.logs
        .filter { $0.value >= habit.dailyTarget }
        .map { calendar.startOfDay(for: $0.date) }
        .sorted()
    var best = 0, current = 0
    var previous: Date? = nil
    for day in sortedDays {
        if let prev = previous,
           calendar.date(byAdding: .day, value: 1, to: prev) == day {
            current += 1
        } else {
            current = 1
        }
        best = max(best, current)
        previous = day
    }
    return best
}

func completionRate30Days(for habit: Habit) -> Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today)!
    let completedDays = Set(
        habit.logs
            .filter { $0.value >= habit.dailyTarget && $0.date >= thirtyDaysAgo }
            .map { calendar.startOfDay(for: $0.date) }
    )
    return Double(completedDays.count) / 30.0
}
```

### Pattern 6: Edit Mode and Reorder

**What:** Use SwiftUI's built-in `EditButton` + `.onMove` on a `ForEach` inside a `List` (or `LazyVStack` with custom drag). After move, update `sortOrder` on all affected habits.

**Recommended approach:** Use a standard `List` in edit mode for the Today view (matches iOS conventions). Cards inside List can be styled with `.listRowBackground` and `.listRowInsets`.

```swift
// sortOrder update after onMove
func moveHabits(_ habits: [Habit], from source: IndexSet, to destination: Int, context: ModelContext) {
    var reordered = habits
    reordered.move(fromOffsets: source, toOffset: destination)
    for (index, habit) in reordered.enumerated() {
        habit.sortOrder = index
    }
    // ModelContext auto-saves changes to @Model properties
}
```

### Pattern 7: Habit Form (Add + Edit Reuse)

**What:** A single `HabitFormView` that accepts an optional existing `Habit`. When nil → create mode; when non-nil → edit mode using `@Bindable`.

```swift
struct HabitFormView: View {
    @Bindable var habit: HabitSchemaV1.Habit  // @Bindable works with @Model
    var isNew: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            TextField("Name", text: $habit.name)
            Picker("Type", selection: $habit.habitType) {
                ForEach(HabitType.allCases, id: \.rawValue) { type in
                    Text(type.rawValue.capitalized).tag(type.rawValue)
                }
            }
            TextField("Daily Target", value: $habit.dailyTarget, format: .number)
            TextField("Unit", text: $habit.unit)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    if isNew { context.insert(habit) }
                    dismiss()
                }
            }
        }
    }
}
```

### Anti-Patterns to Avoid

- **Putting @Query in @Observable ViewModels:** @Query requires SwiftUI's environment; it will not work in a ViewModel. Use @Query in views or inject via init pattern.
- **Using Date.now directly inside #Predicate:** Copy to a local constant first (`let now = Date.now`); the macro cannot capture `Date.now` directly.
- **Calling Calendar(identifier: .gregorian) instead of Calendar.current:** Always use `Calendar.current` for streak and date logic to respect the user's calendar and timezone.
- **Multiple HabitLogs per day for count habits without aggregation:** Either use one log per day (upsert) or always aggregate before comparing to target. Mixed approaches cause incorrect progress display.
- **Storing today's computed value in @Model:** Today's value is derived from logs — do not add a `currentValue` field to the Habit model. Compute on the fly from `habit.logs`.
- **Hardcoding sort by createdAt instead of sortOrder:** The `sortOrder` field exists specifically for user-controlled ordering; always sort by it.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Date boundary for "today" | Manual hour/minute math | `Calendar.current.startOfDay(for: Date())` | Handles DST, leap seconds, timezone changes automatically |
| Consecutive day check | Subtract 86400 seconds | `calendar.isDate(_:inSameDayAs:)` and `calendar.date(byAdding: .day, value: 1, to:)` | 86400s fails on DST days (23h or 25h days) |
| Delete confirmation | Custom modal view | `.confirmationDialog` modifier | iOS-standard appearance, accessible, handles iPad popover automatically |
| Progress bar | Custom GeometryReader | SwiftUI `ProgressView(value:total:)` or a simple `ZStack` with two `RoundedRectangle`s | Built-in ProgressView is accessible; custom ZStack is 3 lines and reliable |
| Stats bar chart | Custom drawing | `Swift Charts` `BarMark` | Accessibility, animation, dark mode all handled |
| List reorder persistence | Core Data sort-index strategy | `onMove` + update `sortOrder` on all reordered habits | SwiftData handles the persistence; just update Int properties |
| Number input formatting | UIKit bridge | `TextField` with `.keyboardType(.decimalPad)` and `value:format:.number` | Native SwiftUI works correctly in iOS 17+ |

**Key insight:** Every "I'll just build a simple version" of calendar math has a DST or timezone edge case. Foundation's Calendar API handles all of them.

---

## Common Pitfalls

### Pitfall 1: @Query Predicate with Date.now

**What goes wrong:** `@Query(filter: #Predicate { $0.date >= Date.now })` fails to compile or produces stale results.

**Why it happens:** The `#Predicate` macro cannot capture `Date.now` as a dynamic expression.

**How to avoid:** Always copy to a local constant before the predicate:
```swift
let startOfDay = Calendar.current.startOfDay(for: Date())
_logs = Query(filter: #Predicate { $0.date >= startOfDay })
```

**Warning signs:** Compile error mentioning "cannot use instance member" or logs always showing yesterday's data.

---

### Pitfall 2: Edit Mode + Cards (List vs. ScrollView)

**What goes wrong:** Using `LazyVStack` inside `ScrollView` for the Today habit list — `onMove` drag handles only work when ForEach is inside a `List`.

**Why it happens:** SwiftUI's move gesture is implemented by `List`; `ScrollView` + `LazyVStack` do not support `onMove`.

**How to avoid:** Use `List` for the Today view. Cards can still be visually styled with `.listRowBackground(Color.clear)` and custom card shapes inside each row. Alternatively, implement a custom drag-to-reorder with `DragGesture` on a `ScrollView`, but this is significantly more complex.

**Recommendation:** Use `List` with styled rows for Today view. The visual difference from a pure `ScrollView + LazyVStack` is minimal with proper row insets.

**Warning signs:** `.onMove` has no visual effect; drag handles don't appear.

---

### Pitfall 3: modelContext.save() Not Needed (But Rollback Is Manual)

**What goes wrong:** Calling `modelContext.save()` after every write is unnecessary — SwiftData auto-saves. But if you need to discard uncommitted changes (e.g., user cancels a new habit form), you must call `modelContext.rollback()` explicitly.

**Why it happens:** SwiftData uses an implicit save cycle. Developers used to CoreData's manual save pattern either over-save (harmless but unnecessary) or forget to rollback on cancel (leaves partial data).

**How to avoid:** For add-new flows, insert the Habit into context immediately and let the user cancel by calling `modelContext.rollback()` in the dismiss handler. Or: create the Habit in-memory (no context insert) and only insert on confirm.

**Recommendation:** Create a local Habit() with default values, populate via form, then `context.insert(habit)` only on "Save" button tap. This avoids the rollback complexity entirely.

**Warning signs:** Cancelled habit creation still appears in the habit list after dismiss.

---

### Pitfall 4: Midnight Reset — App Was Backgrounded

**What goes wrong:** The app was backgrounded at 11:55 PM and foregrounded at 12:05 AM the next day. The Today view still shows yesterday's logs as "today."

**Why it happens:** `@Query` with a static date predicate set at view init time does not re-evaluate when the date changes.

**How to avoid:** In `TodayView`, compute today's date boundary dynamically using `.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification))` to force a view refresh. Alternatively, pass `Date()` into child view inits dynamically so the predicate is re-evaluated each time the view appears.

**Warning signs:** User reports yesterday's completed habits showing as "complete" on the new day.

---

### Pitfall 5: Streak Counting "Today" When Not Yet Completed

**What goes wrong:** Streak shows 1 at 8 AM even though the habit hasn't been logged yet today.

**Why it happens:** The streak algorithm starts from `startOfDay(for: Date())` and finds no log for today, then immediately returns 0 — or conversely, counts an empty "today" as a continuation.

**How to avoid:** Start streak walk from today if today has a log; otherwise start from yesterday. Current streak = 0 if today has no log AND yesterday also has no log (streak is broken).

**Correct logic:** Check if today is completed. If yes, count from today backward. If no, check if yesterday was completed — if yes, the streak is still "alive" (user hasn't had a chance to complete today yet). Display the in-progress streak with a visual indicator. This matches user expectation.

**Warning signs:** Streak resets to 0 every morning until the user logs the habit.

---

### Pitfall 6: HabitType String vs. Enum

**What goes wrong:** The `habitType` field on `HabitSchemaV1.Habit` is stored as `String` (CloudKit-compatible). Switching on it without going through `HabitType(rawValue:)` leads to silent fallthrough if the string value ever changes.

**Why it happens:** @Model does not support Swift enum types natively without a custom transformer (which would break CloudKit compatibility). The raw string approach is intentional.

**How to avoid:** Always convert through the enum:
```swift
guard let type = HabitType(rawValue: habit.habitType) else { return }
switch type {
case .boolean: ...
case .count: ...
case .input: ...
}
```
Never switch directly on `habit.habitType` string.

---

## Code Examples

### Today View — Card Interaction Dispatch

```swift
// HabitCardView.swift
struct HabitCardView: View {
    @Bindable var habit: HabitSchemaV1.Habit
    @Environment(\.modelContext) private var modelContext
    @State private var showingInputSheet = false

    private var habitType: HabitType {
        HabitType(rawValue: habit.habitType) ?? .boolean
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                Text(progressText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if habitType == .count || habitType == .input {
                Button {
                    if habitType == .count {
                        HabitLogService.incrementCount(habit: habit, context: modelContext)
                    } else {
                        showingInputSheet = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if habitType == .boolean {
                HabitLogService.toggleBoolean(habit: habit, context: modelContext)
            }
        }
        .sheet(isPresented: $showingInputSheet) {
            LogInputSheet(habit: habit)
        }
    }
}
```

### Predicate for Today's Logs

```swift
// In a subview init — never use Date.now directly in #Predicate
let startOfDay = Calendar.current.startOfDay(for: Date())
let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
_todayLogs = Query(
    filter: #Predicate<HabitSchemaV1.HabitLog> { log in
        log.habit?.id == habitID && log.date >= startOfDay && log.date < endOfDay
    }
)
```

### Delete with Confirmation

```swift
// In TodayViewModel or inline in TodayView
@State private var habitToDelete: HabitSchemaV1.Habit? = nil

// Trigger:
.swipeActions {
    Button(role: .destructive) {
        habitToDelete = habit
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
.confirmationDialog(
    "Delete \"\(habitToDelete?.name ?? "")\"?",
    isPresented: Binding(get: { habitToDelete != nil }, set: { if !$0 { habitToDelete = nil } }),
    titleVisibility: .visible
) {
    Button("Delete Habit", role: .destructive) {
        if let h = habitToDelete { modelContext.delete(h) }
        habitToDelete = nil
    }
}
```

### 30-Day Bar Chart with Swift Charts

```swift
// In HabitStatsView
import Charts

struct CompletionBarChart: View {
    let completionByDay: [(date: Date, completed: Bool)]  // last 30 days

    var body: some View {
        Chart(completionByDay, id: \.date) { entry in
            BarMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Completed", entry.completed ? 1 : 0)
            )
            .foregroundStyle(entry.completed ? Color.accentColor : Color.secondary.opacity(0.3))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 80)
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ObservableObject` + `@Published` + `@StateObject` | `@Observable` macro + `@State` | iOS 17 / WWDC23 | Eliminates wrapper split; finer view invalidation |
| `IntentTimelineProvider` for widgets | `AppIntentTimelineProvider` (Phase 3) | iOS 17 | Not relevant to Phase 2 but be aware for widget interop |
| `@StateObject` for ViewModel ownership | `@State var viewModel = MyViewModel()` where MyViewModel is `@Observable` | iOS 17 | Less boilerplate; same ownership semantics |
| XCTest for unit tests | Swift Testing (`@Test`, `#expect`) | Xcode 16 | Parameterized date tests are ideal for streak edge cases |
| CoreData FetchRequest + NSPredicate | SwiftData `@Query` + `#Predicate` macro | iOS 17 | Compile-time-validated predicates; Swift-native |

**Deprecated/outdated:**
- `@StateObject` / `@ObservedObject`: Replaced by `@State` with `@Observable`; do not use for new ViewModels in this project
- `NSPredicate` strings: Never use; use `#Predicate` macro for type safety
- `ObservableObject`: Legacy pattern; all new types use `@Observable`

---

## Open Questions

1. **One HabitLog per day vs. multiple logs per day for count/input habits**
   - What we know: `HabitLog.value` is a `Double`; Phase 1 schema has no uniqueness constraint on (habit, date)
   - What's unclear: Whether multiple small log entries per day (e.g., each cup of water separately) are needed for history — currently only the aggregate matters
   - Recommendation: Use **one log per day** (upsert pattern). If multiple-entry history is needed in a future version, a schema migration can add it. This keeps the streak and stats algorithms simpler.

2. **"Today" calculation when app is launched just after midnight**
   - What we know: `Calendar.current.startOfDay(for: Date())` is correct
   - What's unclear: The foreground notification approach for midnight resets — needs a decision on whether to handle this in Phase 2 or leave it as a Phase 4 polish item
   - Recommendation: Implement the `willEnterForegroundNotification` refresh in Phase 2, since it is a requirement (LOG-04) and is trivial to add.

3. **Streak counts "today as in-progress" vs. "today not yet started"**
   - What we know: Current streak should not reset to 0 just because it is 8 AM and the habit hasn't been logged yet
   - Recommendation: If today is incomplete, display yesterday's streak as the "current" value with no visual penalty. Only reset to 0 if yesterday was also incomplete. Document this as the chosen behavior in the plan.

---

## Environment Availability

Step 2.6: Skipped for Phase 2. This phase is purely Swift/SwiftUI code changes with no external service dependencies beyond what was verified in Phase 1 (Xcode 16.3, iOS 17+ simulator/device). The shared App Group container is already established.

---

## Sources

### Primary (HIGH confidence)

- Apple Developer Documentation — SwiftData `@Query` `init(filter:sort:)`: https://developer.apple.com/documentation/swiftdata/query/init(filter:sort:animation:)
- Apple Developer Documentation — Filtering and sorting persistent data: https://developer.apple.com/documentation/swiftdata/filtering-and-sorting-persistent-data
- Apple Developer Documentation — FetchDescriptor: https://developer.apple.com/documentation/swiftdata/fetchdescriptor
- Apple Developer Documentation — Managing model data in your app (SwiftUI + SwiftData): https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app
- Apple Developer Documentation — SwiftUI TabView: https://developer.apple.com/documentation/swiftui/tabview
- Apple Developer Documentation — Swift Charts: https://developer.apple.com/documentation/Charts
- Apple WWDC23 — Dive deeper into SwiftData: https://developer.apple.com/videos/play/wwdc2023/10196/
- CLAUDE.md — Full stack requirements and technology decisions (project file)
- HabitSchemaV1.swift — Existing @Model definitions (project file)
- SharedModelContainer.swift — Container setup (project file)

### Secondary (MEDIUM confidence)

- Hacking with Swift — How to use @Query to read SwiftData objects from SwiftUI: https://www.hackingwithswift.com/quick-start/swiftdata/how-to-use-query-to-read-swiftdata-objects-from-swiftui
- Hacking with Swift — Dynamically sorting and filtering @Query with SwiftUI: https://www.hackingwithswift.com/books/ios-swiftui/dynamically-sorting-and-filtering-query-with-swiftui
- Luke Roberts Blog — Designing and Implementing a Daily Streak System in Swift: https://blog.lukeroberts.co/posts/streak-system/
- Sarunw — How to Reorder List rows in SwiftUI List: https://sarunw.com/posts/swiftui-list-onmove/
- Use Your Loaf — SwiftUI Confirmation Dialogs: https://useyourloaf.com/blog/swiftui-confirmation-dialogs/
- SwiftUI EnvironmentValues.timezone (Apple): https://developer.apple.com/documentation/swiftui/environmentvalues/timezone

### Tertiary (LOW confidence)

- Community patterns around @Observable + SwiftData MVVM split (multiple Medium/DEV articles — consistent with Apple documentation guidance)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Apple frameworks only; all verified in official docs and established in CLAUDE.md
- Architecture patterns: HIGH — @Query-in-view pattern is confirmed Apple guidance; streak algorithm is standard calendar math
- Pitfalls: HIGH — List vs. LazyVStack onMove limitation is a well-documented SwiftUI constraint; Date.now in predicates is confirmed in Apple forums; others are logic-level
- Stats/History: MEDIUM — Streak "in-progress today" UX behavior is a design decision, not a technical constraint; recommendation is defensible but should be confirmed in CONTEXT or PLAN

**Research date:** 2026-03-29
**Valid until:** 2026-07-01 (stable Apple frameworks; re-verify if Xcode 17/iOS 18 ships before then)
