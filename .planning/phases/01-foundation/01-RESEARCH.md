# Phase 1: Foundation — Research

**Researched:** 2026-03-27
**Domain:** iOS infrastructure — SwiftData + App Groups + VersionedSchema + Swift 6 concurrency
**Confidence:** HIGH

---

## Summary

Phase 1 is pure infrastructure with no UI. Every decision made here either prevents a catastrophic failure or enables a smooth v2 CloudKit migration. All four requirements (INFRA-01 through INFRA-04) address problems that cannot be fixed retroactively without user-facing data loss or forced app deletion.

The standard pattern is well-documented: create a new Xcode project with a widget extension target, add App Groups capability to both targets using the same group identifier, define SwiftData models wrapped inside a `HabitSchemaV1: VersionedSchema` enum, initialize a static `SharedModelContainer` singleton pointing at the App Group store via `ModelConfiguration(groupContainer: .identifier(...))`, and use `@MainActor` for all SwiftUI-connected data access while treating `ModelContainer` and `PersistentIdentifier` as the only Sendable types across actor boundaries.

The single most important deliverable is a TestFlight smoke test confirming that the widget extension can read from the shared store — Debug-only verification is insufficient because Xcode's automatic provisioning silently diverges between Debug and Release entitlements.

**Primary recommendation:** Use `ModelConfiguration(groupContainer: .identifier("group.com.yourname.HabitX"))` — NOT the manual FileManager URL pattern. This is the modern SwiftData-native approach and handles automatic store migration if the group identifier is added later.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-01 | All data stored on-device using SwiftData with App Groups for widget access | SharedModelContainer pattern with `groupContainer: .identifier(...)` — both targets point to same SQLite store |
| INFRA-02 | SwiftData schema uses VersionedSchema from initial build (migration-safe for future updates) | `HabitSchemaV1: VersionedSchema` + `HabitMigrationPlan` with empty `stages: []` — must be in place before first TestFlight |
| INFRA-03 | All SwiftData model attributes are optional or have defaults (CloudKit-compatible for future v2) | All `String = ""`, `Int = 0`, `Double = 0.0`, `Bool = false`, `[T] = []` defaults required; no non-optional relationships |
| INFRA-04 | App and widget extension share the same App Group container identifier | Identical `group.com.yourname.HabitX` in both target entitlements; verified in Apple Developer portal AND TestFlight |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

| Constraint | Directive |
|------------|-----------|
| Platform | Native iOS (Swift/SwiftUI) only |
| Widget interactivity | iOS 17+ required — hard floor |
| Text input in widgets | Not supported — input habits must open the app |
| Storage | On-device SwiftData v1, designed to migrate to CloudKit later |
| Complexity | Keep simple — every decision reduces friction |
| Stack | Apple frameworks only — no third-party dependencies |
| Language mode | Swift 6 strict concurrency from project start |
| Xcode | 16.3+ (iOS 18 SDK required for App Store submissions) |
| Testing | Swift Testing (`@Test`, `#expect`) for unit tests; XCTest for UI tests only |
| Workflow | All edits through GSD commands — no direct repo edits outside a GSD workflow |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift | 6.1 (Xcode 16.3) | Language | App Store requires Xcode 16+; Swift 6 strict concurrency is current baseline |
| SwiftUI | iOS 17+ | All UI + widget views | WidgetKit is SwiftUI-only; no UIKit needed |
| SwiftData | iOS 17+ | On-device persistence | Apple-native successor to CoreData; `@Model` macro, `@Query`, direct WidgetKit integration |
| WidgetKit | iOS 17+ | Widget extension scaffold | Only framework for iOS home screen widgets |
| AppIntents | iOS 17+ | Widget interactivity (Phase 3) | Interactive widget buttons require AppIntents; SiriKit Intents deprecated |

### Supporting (Phase 1 specific)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| App Groups entitlement | iOS 8+ | Shared container between app and widget | Required — without it each process gets a separate empty SQLite store |
| VersionedSchema (SwiftData) | iOS 17+ | Schema versioning from day one | Must be defined before first TestFlight — unversioned stores cannot be migrated later |
| SchemaMigrationPlan (SwiftData) | iOS 17+ | Migration anchor for future schema changes | Define with empty `stages: []` in v1; add stages as schema evolves in v2+ |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `groupContainer: .identifier(...)` | `url: FileManager.containerURL(...)` | Manual URL is the CoreData-era pattern; `groupContainer` is SwiftData-native and handles automatic store migration automatically |
| `@Model` classes inside `VersionedSchema` extension | Top-level `@Model` classes with no versioning | Without versioning, any future schema change crashes existing users on launch — no recovery path |
| `try ModelContainer(for:migrationPlan:configurations:)` with fatalError on catch | `try?` or optional container | Container initialization failure should be fatal — silent failure means data loss |

**Installation:** No package dependencies. All frameworks are Apple system frameworks, no `npm install` or SPM packages needed.

---

## Architecture Patterns

### Recommended Project Structure

```
HabitX/
├── HabitXApp.swift               # @main entry, attaches SharedModelContainer
├── Models/
│   ├── Schema/
│   │   ├── HabitSchemaV1.swift   # VersionedSchema enum + nested @Model classes (BOTH targets)
│   │   └── HabitMigrationPlan.swift  # SchemaMigrationPlan (BOTH targets)
│   └── SharedModelContainer.swift    # Static singleton ModelContainer (BOTH targets)
├── Views/
│   └── ContentView.swift         # Placeholder for Phase 1
└── HabitXWidget/
    ├── HabitXWidget.swift         # Widget entry point, attaches SharedModelContainer
    └── HabitXWidgetBundle.swift   # @main for widget extension
```

**Target membership rule:** `HabitSchemaV1.swift`, `HabitMigrationPlan.swift`, and `SharedModelContainer.swift` must have both "HabitX" AND "HabitXWidget" checked in Xcode's File Inspector → Target Membership panel.

---

### Pattern 1: VersionedSchema Definition (V1 only — no migration stages yet)

**What:** Wrap all `@Model` classes inside a `VersionedSchema` enum from day one. The enum namespaces the models to their schema version, establishing a migration anchor SwiftData can use for all future migrations.

**When to use:** Before the first build deployed to TestFlight or App Store — this cannot be added retroactively.

```swift
// HabitSchemaV1.swift — added to BOTH app and widget targets
import SwiftData

enum HabitSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [HabitSchemaV1.Habit.self, HabitSchemaV1.HabitLog.self]
    }
}

extension HabitSchemaV1 {
    @Model
    final class Habit {
        var id: UUID = UUID()
        var name: String = ""
        var habitType: String = "boolean"  // "boolean" | "count" | "input"
        var dailyTarget: Double = 1.0
        var unit: String = ""
        var reminderTime: Date? = nil
        var createdAt: Date = Date()
        var sortOrder: Int = 0

        @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
        var logs: [HabitLog] = []

        init() {}
    }

    @Model
    final class HabitLog {
        var id: UUID = UUID()
        var date: Date = Date()        // normalized to Calendar.current.startOfDay
        var value: Double = 0.0
        var loggedAt: Date = Date()
        var habit: Habit? = nil

        init() {}
    }
}
```

**Key design decisions baked into this model:**
- `habitType` is `String` not an enum — enums stored as `RawRepresentable` are supported by SwiftData but can cause CloudKit issues if the rawValue type changes; `String` is the safest default.
- All properties have explicit defaults — CloudKit requires this.
- `habit: Habit? = nil` — relationship is optional, satisfying CloudKit's "no required relationships" rule.
- `logs: [HabitLog] = []` — empty array default on the owning side.
- `deleteRule: .cascade` — when a Habit is deleted, all its logs are deleted too.
- No `@Attribute(.unique)` constraints — CloudKit forbids uniqueness constraints.
- `id: UUID = UUID()` — explicit rather than relying on SwiftData's implicit PersistentIdentifier.

---

### Pattern 2: SchemaMigrationPlan (V1 only — empty stages)

**What:** Define the migration plan before any migration exists. With one version in `schemas` and empty `stages`, SwiftData establishes the version anchor without performing any migration.

```swift
// HabitMigrationPlan.swift — added to BOTH app and widget targets
import SwiftData

enum HabitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [HabitSchemaV1.self]
    }
    // No stages yet — V1 is the initial version
    static var stages: [MigrationStage] { [] }
}
```

**When V2 is needed:** Add `HabitSchemaV2.self` to `schemas`, add a `MigrationStage.lightweight(fromVersion: HabitSchemaV1.self, toVersion: HabitSchemaV2.self)` to `stages`. Lightweight stages work for adding optional properties or new models — no custom migration closure needed.

---

### Pattern 3: SharedModelContainer Singleton

**What:** A static singleton that both the app and widget extension instantiate from. Both targets must use the identical group identifier and schema; this is what guarantees they read/write the same SQLite file.

```swift
// SharedModelContainer.swift — added to BOTH app and widget targets
import SwiftData

enum SharedModelContainer {
    static let container: ModelContainer = {
        let schema = Schema(versionedSchema: HabitSchemaV1.self)
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.com.yourname.HabitX")
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: HabitMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
```

**Main app attachment:**
```swift
// HabitXApp.swift
import SwiftUI
import SwiftData

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

**Widget extension attachment:**
```swift
// HabitXWidget.swift
import WidgetKit
import SwiftUI
import SwiftData

struct HabitXWidget: Widget {
    let kind: String = "HabitXWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitTimelineProvider()) { entry in
            HabitWidgetEntryView(entry: entry)
                .modelContainer(SharedModelContainer.container)
        }
        .configurationDisplayName("HabitX")
        .description("Track your daily habits.")
    }
}
```

**`try!` vs `fatalError`:** The `fatalError` approach (via `do/catch`) is preferable to `try!` — identical behavior but gives a diagnostic message in the crash log that identifies which configuration caused the failure.

---

### Pattern 4: App Group Entitlement Configuration (Xcode steps)

**Step-by-step:**

1. In Xcode, select the **HabitX** app target → Signing & Capabilities tab
2. Click **+ Capability** → search "App Groups" → double-click to add
3. Click **+** in the App Groups list → enter identifier: `group.com.yourname.HabitX`
4. Select the **HabitXWidget** extension target → Signing & Capabilities tab
5. Click **+ Capability** → "App Groups" → double-click to add
6. In the App Groups list, **check the existing** `group.com.yourname.HabitX` (do not create a new one)

Xcode's automatic signing will regenerate provisioning profiles. Both targets' `.entitlements` files will contain:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourname.HabitX</string>
</array>
```

**Developer portal verification:** After adding the capability, open https://developer.apple.com/account → Identifiers, find both App IDs (the main app bundle ID and the widget extension bundle ID), and confirm `group.com.yourname.HabitX` is listed under App Groups for each. If it is not listed, Xcode's automatic signing may not have synced — regenerate profiles manually.

---

### Pattern 5: Swift 6 Concurrency in the Data Layer

**Rules for Swift 6 + SwiftData:**

| Object | Sendable? | Rule |
|--------|-----------|------|
| `ModelContainer` | YES | Safe to pass across actors and store as static |
| `PersistentIdentifier` | YES | Use as the cross-actor currency — not model objects |
| `ModelContext` | NO | Must be created and used on a single actor |
| `@Model` class instances | NO | Cannot cross actor boundaries |

**ViewModels (main app):** Mark all ViewModels `@MainActor`. `ModelContext` obtained from SwiftUI's `@Environment(\.modelContext)` is always `@MainActor`-isolated. This is the correct approach for all CRUD in the main app.

```swift
// TodayViewModel.swift
import SwiftData
import Observation

@MainActor
@Observable
final class TodayViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func logHabit(_ habit: HabitSchemaV1.Habit, value: Double) throws {
        let log = HabitSchemaV1.HabitLog()
        log.date = Calendar.current.startOfDay(for: .now)
        log.value = value
        log.habit = habit
        modelContext.insert(log)
        try modelContext.save()
    }
}
```

**AppIntents (widget — Phase 3):** Widget extension `AppIntent.perform()` runs outside the main actor. Create a fresh `ModelContext` from `SharedModelContainer.container` inside `perform()` — do not attempt to reuse the app's context.

```swift
// Phase 3 preview — establish this pattern in Phase 1's architecture
struct ToggleHabitIntent: AppIntent {
    @Parameter var habitId: String

    // perform() is nonisolated by default in AppIntents
    func perform() async throws -> some IntentResult {
        let context = ModelContext(SharedModelContainer.container)
        // Fetch, mutate, save — all within this context
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

**Swift 6 compiler warnings to expect and fix:**
- `SchemaMigrationPlan` and `VersionedSchema` conformances may trigger "not Sendable" warnings in Swift 6 mode — this is a known framework issue (Swift Forums thread/75731). The workaround is to mark the enum `@unchecked Sendable` with a comment explaining this is a framework limitation, not a design choice.
- `@Model` classes get `@MainActor` isolation by default in some Xcode versions — if you see unexpected actor-isolation errors on model accesses in non-MainActor contexts (e.g., widget AppIntents), consult the fix: ensure the context doing the work was created on the same actor, or use `nonisolated` on model initialization.

---

### Anti-Patterns to Avoid

- **Top-level `@Model` classes without VersionedSchema:** Any future schema change causes crash-on-launch for all existing users. No recovery path.
- **Different group identifiers on app vs. widget:** Each process silently creates its own empty SQLite store. Widget shows no data immediately.
- **Multiple `ModelContainer` instantiations per process:** Use the static singleton everywhere. Multiple instantiations can cause SQLite lock contention.
- **Using `.atEnd` timeline policy on the widget:** This causes unnecessary refreshes and drains the ~40-70 daily refresh budget. Use `.after(nextMidnight)` instead (Phase 3 concern, but document now).
- **Setting `@Attribute(.unique)` on any model property:** CloudKit forbids uniqueness constraints — they compile fine locally but silently break CloudKit activation.
- **Non-optional relationship on `HabitLog.habit`:** If this is non-optional and a `Habit` is deleted, CloudKit sync will fail. Keep `habit: Habit? = nil`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Shared store between app + widget | Custom file-copy mechanism | `ModelConfiguration(groupContainer: .identifier(...))` | SwiftData handles the shared container path natively; manual approaches drift |
| Schema versioning | Custom version metadata in UserDefaults | `VersionedSchema` + `SchemaMigrationPlan` | SwiftData's migration engine requires its own version anchors — external tracking doesn't help |
| Model change tracking | Custom dirty flags / timestamps | SwiftData's built-in `ModelContext.hasChanges` and `save()` | SwiftData tracks changes automatically |
| CloudKit compatibility audit | Runtime checks | Design constraints at model definition time (all defaults) | Constraints are build-time, not runtime — audit at model creation, not deployment |

**Key insight:** The App Groups + VersionedSchema infrastructure is 100 lines of boilerplate. Every custom alternative to these patterns introduces a failure mode that only appears in production, not Simulator.

---

## Common Pitfalls

### Pitfall 1: Skipping VersionedSchema (CATASTROPHIC)
**What goes wrong:** Without `VersionedSchema`, any future schema change crashes on launch for ALL existing users. SwiftData cannot reconcile an unversioned original schema with a new versioned one.
**Why it happens:** Every beginner tutorial shows `@Model class Habit { var name: String }` without versioning — it compiles, it works, it seems fine.
**How to avoid:** Define `HabitSchemaV1: VersionedSchema` before the first TestFlight build. Even with `stages: []`, the migration anchor is established.
**Warning signs:** Any code using bare `@Model` without a wrapping VersionedSchema enum.

### Pitfall 2: App Groups on Only One Target
**What goes wrong:** Widget creates its own empty SQLite store. No errors raised — widget just shows no data on first use.
**Why it happens:** Adding App Groups to the app target is the obvious step; the widget target is easy to miss.
**How to avoid:** After adding App Groups, check BOTH targets in Signing & Capabilities. Then verify in the Apple Developer portal that both App IDs have the group listed.
**Warning signs:** Widget renders a placeholder or empty state immediately after install, even when habits exist in the main app.

### Pitfall 3: Non-Optional/No-Default Model Fields
**What goes wrong:** Models compile and run locally but CloudKit sync silently fails to activate in v2. Worse, if any field is non-optional `String` (e.g., `var name: String`), CloudKit-enabled `ModelContainer` initialization crashes.
**Why it happens:** Swift's type system makes non-optional the natural choice. CloudKit's schema rules (inherited from Core Data) require the opposite.
**How to avoid:** Every `String`, `Int`, `Double`, `Bool`, `Date` property must have a default value. Every relationship must be optional or initialized to an empty array.
**Warning signs:** `var name: String` with no `= ""` — any model property without a default is a CloudKit blocker.

### Pitfall 4: Debug/Release Provisioning Profile Drift (Pitfall 13 from PITFALLS.md)
**What goes wrong:** App Groups work in Debug simulator/device builds but the widget has no data in TestFlight (Release build).
**Why it happens:** Xcode's automatic signing regenerates provisioning profiles on demand. Adding a new capability to one target may not immediately update the other target's Release profile.
**How to avoid:** After configuring App Groups, run the project on a physical device in Release configuration (or submit a TestFlight build) and verify the widget reads data. Do NOT mark Phase 1 complete on Simulator-only verification.
**Warning signs:** Widget shows data in Debug on device, blank in TestFlight.

### Pitfall 5: `groupContainer` API vs. Explicit URL — Using the Wrong One
**What goes wrong:** STACK.md documents two patterns: `ModelConfiguration(groupContainer: .identifier(...))` and `ModelConfiguration(url: FileManager.containerURL(...))`. Using the URL approach works but does not trigger SwiftData's automatic store migration path.
**Why it happens:** The URL approach is extensively documented for Core Data; many SwiftData tutorials carry it over.
**How to avoid:** Use `groupContainer: .identifier("group.com.yourname.HabitX")` — this is the SwiftData-native API that handles automatic migration of existing stores to the group container.

---

## Code Examples

### Complete HabitSchemaV1 with all fields and defaults

```swift
// Source: Confirmed pattern from atomicrobot.com + azamsharp.com + Apple WWDC23
// HabitSchemaV1.swift — Target Membership: HabitX + HabitXWidget

import SwiftData

enum HabitSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [HabitSchemaV1.Habit.self, HabitSchemaV1.HabitLog.self]
    }
}

extension HabitSchemaV1 {
    @Model
    final class Habit {
        var id: UUID = UUID()
        var name: String = ""
        var habitType: String = "boolean"  // raw value for HabitType enum
        var dailyTarget: Double = 1.0
        var unit: String = ""
        var reminderTime: Date? = nil
        var createdAt: Date = Date()
        var sortOrder: Int = 0

        @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
        var logs: [HabitLog] = []

        init() {}
    }

    @Model
    final class HabitLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var value: Double = 0.0
        var loggedAt: Date = Date()
        var habit: Habit? = nil

        init() {}
    }
}

// Domain enum — NOT stored as-is in SwiftData (use rawValue String)
enum HabitType: String, CaseIterable {
    case boolean
    case count
    case input
}
```

### Complete HabitMigrationPlan

```swift
// Source: Confirmed pattern from atomicrobot.com + Apple WWDC23 session
// HabitMigrationPlan.swift — Target Membership: HabitX + HabitXWidget

import SwiftData

enum HabitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [HabitSchemaV1.self]
    }
    static var stages: [MigrationStage] { [] }
    // No migration stages needed in V1 — this establishes the anchor.
    // When V2 is added: append HabitSchemaV2.self to schemas,
    // add MigrationStage.lightweight(fromVersion: HabitSchemaV1.self, toVersion: HabitSchemaV2.self)
}
```

### Complete SharedModelContainer

```swift
// Source: Confirmed pattern from appmakers.dev article (Jun 2025) + Apple Developer Forums
// SharedModelContainer.swift — Target Membership: HabitX + HabitXWidget

import SwiftData

enum SharedModelContainer {
    static let container: ModelContainer = {
        let schema = Schema(versionedSchema: HabitSchemaV1.self)
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.com.yourname.HabitX")
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: HabitMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("SharedModelContainer: failed to initialize — \(error)")
        }
    }()
}
```

### Verification test — confirm App Group store path

```swift
// Add to Phase 1 smoke test: verify both targets use the same store URL
// Run in app AND widget extension; both should print the same path
func logStoreURL() {
    let url = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.yourname.HabitX"
    )
    print("App Group container URL: \(url?.absoluteString ?? "NIL — App Group NOT configured")")
}
```

If either target prints `NIL`, the App Group entitlement is missing or the identifier is misspelled.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@Model class Habit { var name: String }` (bare, unversioned) | `enum HabitSchemaV1: VersionedSchema` with nested `@Model` | iOS 17 / WWDC23 | Required for any migration; non-optional without it |
| `ModelConfiguration(url: FileManager.containerURL(...))` | `ModelConfiguration(groupContainer: .identifier(...))` | iOS 17 SwiftData | Native API with automatic store migration; URL approach is CoreData-era |
| `ObservableObject` + `@Published` for ViewModels | `@Observable` macro | iOS 17 | Fine-grained re-render; less boilerplate; no more `@StateObject`/`@ObservedObject` split |
| `IntentTimelineProvider` (SiriKit Intents) | `AppIntentTimelineProvider` (AppIntents) | iOS 17 | Required for interactive widgets; SiriKit path is deprecated |

**Deprecated/outdated:**
- `@StateObject`/`@ObservedObject`: still functional but not idiomatic for iOS 17+ new code
- SiriKit Intents for widget configuration: deprecated in favor of AppIntents
- `try!` for container initialization: replace with `do/catch` + `fatalError` for diagnostics

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16.3+ | Build tooling | Verify before starting | — | Must upgrade — App Store requires Xcode 16+ |
| iOS 17+ device or simulator | SwiftData + interactive widgets | Available in Xcode 16 simulators | — | Simulator is sufficient for Phase 1; physical device required for Phase 1 sign-off (provisioning verification) |
| Apple Developer account (paid) | App Groups provisioning, TestFlight | Required | — | No fallback — free account cannot create App Groups |
| Physical device (any iPhone iOS 17+) | TestFlight smoke test (Phase 1 sign-off) | User's physical device | — | Phase 1 cannot be signed off on Simulator alone |

**Missing dependencies with no fallback:**
- Paid Apple Developer account — App Groups entitlement requires a paid account; free accounts cannot configure App Groups in the portal
- Physical iOS device — Debug/Release provisioning drift cannot be verified on Simulator

---

## Open Questions

1. **Bundle ID / App Group identifier**
   - What we know: The identifier format should be `group.com.yourname.HabitX` where `yourname` matches the developer account's reverse-domain prefix
   - What's unclear: The actual bundle ID is not set in any planning document
   - Recommendation: Decide on the bundle ID before project creation — it is embedded in entitlements files and changing it after App Group configuration requires re-provisioning

2. **`HabitType` as String vs. enum stored via `@Attribute`**
   - What we know: SwiftData supports `RawRepresentable` enums; CloudKit supports them IF the raw type is `String` or `Int`
   - What's unclear: Whether `@Attribute` is needed or if the `RawRepresentable` conformance is implicit
   - Recommendation: Store as `String` with a non-stored `HabitType` enum used at the business logic layer — this is the safest approach and avoids any `@Attribute` nuance

3. **Swift 6 `SchemaMigrationPlan` Sendable warning**
   - What we know: Swift Forums thread/75731 documents that `SchemaMigrationPlan` and `VersionedSchema` are not marked `Sendable` as of Swift 6, causing compiler warnings in strict concurrency mode
   - What's unclear: Whether Apple has resolved this in Swift 6.1 or 6.2
   - Recommendation: If the warning appears, suppress with `@unchecked Sendable` and a comment — do not disable strict concurrency mode across the module

---

## Sources

### Primary (HIGH confidence)
- Apple WWDC23 "Meet SwiftData" session — SwiftData architecture, VersionedSchema, App Group integration
- Apple WWDC23 "Model your schema with SwiftData" — VersionedSchema and SchemaMigrationPlan patterns
- Apple Developer Documentation — ModelConfiguration.GroupContainer: https://developer.apple.com/documentation/swiftdata/modelconfiguration/groupcontainer-swift.struct
- Apple Developer Documentation — ModelConfiguration.init with groupContainer: https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(_:schema:isstoredinmemoryonly:allowssave:groupcontainer:cloudkitdatabase:)
- Apple Developer Forums — SwiftData and correct setup for App Groups: https://developer.apple.com/forums/thread/732986
- Apple Developer Forums — Add App Group to Existing SwiftData: https://developer.apple.com/forums/thread/789173
- Apple Developer Forums — SwiftData unversioned migration: https://developer.apple.com/forums/thread/761735
- Apple Developer Forums — SwiftData CloudKit integration requirements: https://developer.apple.com/forums/thread/735349

### Secondary (MEDIUM confidence)
- atomicrobot.com — An Unauthorized Guide to SwiftData Migrations: https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/
- azamsharp.com — If You Are Not Versioning Your SwiftData Schema: https://azamsharp.com/2026/02/14/if-you-are-not-versioning-your-swiftdata-schema.html
- appmakers.dev — How to Build a Configurable SwiftUI Widget with App Intents and SwiftData (Jun 2025): https://medium.com/app-makers/how-to-build-a-configurable-swiftui-widget-with-app-intents-and-swiftdata-e4db410cfd12
- useyourloaf.com — Sharing data with a Widget: https://useyourloaf.com/blog/sharing-data-with-a-widget/
- fatbobman.com — Rules for Adapting Data Models to CloudKit: https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/
- Swift Forums — SwiftData SchemaMigrationPlan not Sendable (Swift 6): https://forums.swift.org/t/swiftdata-schemamigrationplan-and-versionedschema-not-sendable/75731

### Tertiary (LOW confidence — verify before relying on)
- Medium articles on SwiftData concurrency — patterns are consistent with official docs but not directly verified against official source

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Apple frameworks, confirmed against official docs and multiple cross-referenced implementation articles
- Architecture patterns (VersionedSchema, SharedModelContainer): HIGH — confirmed against Apple Forums, WWDC23, and 2025 implementation articles
- ModelConfiguration `groupContainer` API: HIGH — confirmed via Apple official documentation URL and 2025 article
- Swift 6 concurrency in data layer: MEDIUM — core rules (Sendable/not-Sendable) are HIGH; specific AppIntent patterns are MEDIUM (official docs confirm the rule; specific `perform()` pattern is derived from rules, not an official sample)
- Pitfalls: HIGH — sourced from Apple Developer Forums documenting real production failures

**Research date:** 2026-03-27
**Valid until:** 2026-06-27 (stable APIs — SwiftData, App Groups, VersionedSchema are not fast-moving)
