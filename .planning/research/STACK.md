# Technology Stack

**Project:** HabitX 2.0
**Researched:** 2026-03-27
**Overall confidence:** HIGH — all core framework choices are Apple-first, confirmed via official docs and verified secondary sources

---

## Recommended Stack

### Language

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift | 6.1 (Xcode 16.3) or 6.2 (Xcode 17) | Primary language | Swift 6.x strict concurrency is the current App Store submission baseline. As of April 2025, App Store Connect requires Xcode 16+ with iOS 18 SDK. Swift 6.2 introduced "single-threaded by default" semantics that make concurrency far less boilerplate-heavy for a SwiftUI app. Use Swift 6.1 (Xcode 16.3) now; upgrade to 6.2 when Xcode 17 ships. |

**Concurrency model:** Enable Swift 6 language mode from project start. Use `@MainActor` for all ViewModels (SwiftUI views are automatically `@MainActor`). Use actors only for the notification scheduling service, which must access state from background contexts. Do not fight the compiler — fix every data-race warning at definition time rather than suppressing.

**Confidence:** HIGH — Swift 6.1 confirmed released March 2025 (Xcode 16.3). Swift 6.2 confirmed released September 2025.

---

### UI Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftUI | iOS 17+ API surface | All UI: Today view, History, Stats, Settings | SwiftUI is mandatory once you choose WidgetKit — widget views are SwiftUI-only. Using UIKit for the main app and SwiftUI for widgets creates dual codebases with no benefit. SwiftUI on iOS 17+ has the full API surface needed: NavigationStack, charts (Swift Charts), sheets, lists, and the Observation framework. |
| Swift Charts | iOS 16+ (bundled with SwiftUI) | Stats view — streak graphs, completion rates | Built into SwiftUI, zero extra dependency. Handles the simple bar/line charts HabitX needs. |

**Do NOT use UIKit.** The only valid reason to reach for UIKit in this project would be a custom UI control that SwiftUI cannot express. That does not exist here. UIKit + SwiftUI bridging (UIViewRepresentable) adds code surface and is unnecessary.

**Confidence:** HIGH

---

### State Management

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Observation framework (`@Observable`) | iOS 17+ | ViewModel layer — all app state | `@Observable` replaces `ObservableObject` + `@Published`. All stored properties are automatically tracked; views re-render only when properties they actually read change (fine-grained invalidation vs. coarse ObservableObject). Less boilerplate. Requires iOS 17+, which this project already targets. |
| `@State` / `@Binding` / `@Environment` | SwiftUI built-in | Local view state and dependency injection | With `@Observable`, the old `@StateObject`/`@ObservedObject` wrapper split is gone. Own an `@Observable` ViewModel with `@State`. Pass it down as a plain property or via `@Environment`. |

**Do NOT use Combine** for reactive state. Swift Concurrency (`async/await`, `AsyncSequence`, `.task(id:)`) replaces Combine's role in ViewModels. Combine is still available but it is not the idiomatic 2025 approach for new SwiftUI code.

**Do NOT use TCA (The Composable Architecture) or other third-party architectures.** HabitX is a focused single-domain app. Third-party architecture frameworks add dependency weight and conceptual overhead that is not justified.

**Confidence:** HIGH

---

### Persistence

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftData | iOS 17+ | On-device storage for all habits and log entries | SwiftData is Apple's declared successor to CoreData. For a greenfield iOS 17+ app, SwiftData delivers: Swift-native `@Model` macro, automatic `@Observable` conformance on models (models are directly observable), declarative `@Query` in views, and a clear migration path to CloudKit sync (`ModelConfiguration` with `cloudKitContainerIdentifier`). It integrates directly into WidgetKit via `modelContainer()` in the widget configuration. |

**Specific SwiftData decisions for HabitX:**

- Store the SwiftData database in an **App Group container** from day one. This is the mechanism that makes the same persistent store readable by both the main app and the widget extension. Configure using `ModelConfiguration(url: appGroupStoreURL)` where `appGroupStoreURL` is derived from `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`. If you add App Group support after initial launch, SwiftData will auto-migrate the store — but setting this up at project creation avoids that complexity entirely.
- Add all `@Model` Swift files to **both the app target and the widget extension target** in Xcode.
- Future CloudKit migration: Add `cloudKitContainerIdentifier` to `ModelConfiguration`. Constraints apply (all relationships optional, no uniqueness constraints, no Deny deletion rules) — design the data model with these rules in mind from the start.

**Do NOT use CoreData.** CoreData remains more capable for complex graph queries and shared/public CloudKit databases, but HabitX has a simple data model (habits + daily log entries) that SwiftData handles cleanly. The complexity CoreData adds is not worth it for this scope.

**Confidence:** HIGH — SwiftData iOS 17+ minimum confirmed. App Groups + widget integration pattern confirmed via multiple sources including Apple Developer Forums.

---

### Widget Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| WidgetKit | iOS 17+ | Home screen widgets for each habit | WidgetKit is the only supported framework for iOS home screen widgets. No alternative exists. |
| AppIntents | iOS 17+ | Interactive widget actions (tap to increment, tap to toggle) | Interactive widgets require `Button` and `Toggle` with an `AppIntent`-based initializer. This is the iOS 17 API — `AppIntentTimelineProvider` replaces the old `IntentTimelineProvider`. Each habit action (toggle boolean, increment counter) is an `AppIntent` subtype. The `perform()` method writes to SwiftData via the shared App Group container, then calls `WidgetCenter.shared.reloadTimelines(ofKind:)` to refresh widget display. |

**Interactive widget constraints (confirmed iOS 17+):**

- `Button` and `Toggle` with `AppIntent` initializers: supported iOS 17+
- Text field input in widgets: NOT supported on any iOS version — input habits (protein) must deep-link into the app to log a value. This is a known platform constraint confirmed in PROJECT.md.
- Lock screen widgets: Interactive buttons/toggles are inactive on a locked device until the user unlocks. Design UX accordingly.
- Widget memory budget: Apple expanded the widget memory footprint in 2025 updates, but widgets are still constrained. Keep widget view hierarchies lightweight.

**Do NOT attempt SiriKit Intents** (the old pre-iOS 17 widget intent system). Apple migrated WidgetKit to AppIntents in iOS 17 and deprecated the SiriKit path. New projects must use AppIntents.

**Confidence:** HIGH — iOS 17 interactive widget requirement confirmed via official WWDC23 "Bring widgets to life" session and multiple implementation articles.

---

### Notifications

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| UserNotifications framework (`UNUserNotificationCenter`) | iOS 10+ (current API) | Per-habit daily reminder notifications | This is the only framework for local notifications on iOS. No third-party library needed. Use `UNCalendarNotificationTrigger` with `dateMatching:` for daily repeating notifications at a user-set time. A single `repeats: true` trigger counts as one notification slot. |

**iOS 64 notification slot limit — critical design constraint:**

iOS allows a maximum of 64 pending local notifications per app. `repeats: true` triggers count as one slot each. With HabitX's default of two habits (Protein, Water) and the expectation of a handful of user-created habits, this limit is not a concern in v1. Design the notification manager to:

1. Use `repeats: true` on `UNCalendarNotificationTrigger` so each habit consumes exactly one slot regardless of how far into the future scheduling extends.
2. Reschedule all notifications when the app launches (foreground) and when habit settings change.
3. Call `removeAllPendingNotificationRequests()` before re-scheduling to avoid duplicates.
4. At scale (if users ever have 60+ habits), the workaround is to reschedule the nearest N notifications on app open and use `UNUserNotificationCenter` delegate foreground delivery to reschedule — but this is not a v1 concern.

**Confidence:** HIGH — UNUserNotificationCenter is stable and well-documented. The 64-slot limit is confirmed in Apple Developer Forums.

---

### Data Sharing (App ↔ Widget)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| App Groups entitlement | iOS 8+ | Shared container between app target and widget extension | Required for SwiftData store sharing. Both targets must have the same App Group identifier in their entitlements. The `AppIntent` `perform()` method in the widget writes through the shared SwiftData container and triggers `WidgetCenter.shared.reloadTimelines`. |
| `WidgetCenter` | iOS 14+ | Trigger widget timeline refresh from app | When the main app logs a habit, call `WidgetCenter.shared.reloadAllTimelines()` (or the specific kind) to push a fresh snapshot to the widget. |

**Confidence:** HIGH

---

### Testing

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift Testing (`@Test`, `#expect`) | Xcode 16 / Swift 6 | Unit tests for business logic — habit models, streak calculation, notification scheduling logic | Swift Testing is the modern Apple-native test framework introduced at WWDC24. Ships in Xcode 16. Supports native async/await tests, parallel test execution by default, parameterized tests (`@Test(arguments:)`), and dramatically less boilerplate than XCTest. Use for all new unit tests in HabitX. |
| XCTest | Xcode built-in | UI tests only | Swift Testing does not yet support UI Testing or performance tests (as of 2025). Use XCTest's `XCUIApplication` for any UI automation tests. Unit tests should be in Swift Testing. Both frameworks coexist in the same test target. |

**Do NOT write new unit tests in XCTest.** Write unit tests in Swift Testing. Migrate only if there is a specific XCTest feature needed (performance baselines, UI testing).

**Confidence:** HIGH — Swift Testing in Xcode 16 confirmed. Limitation (no UI/performance tests) confirmed.

---

### Build Tooling

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Xcode | 16.3+ (16.x series) | IDE, build system, simulator | Required for Swift 6.1 and iOS 18 SDK. App Store submissions require Xcode 16+ as of April 2025. |
| Swift Package Manager (SPM) | Built into Xcode | Dependency management (if any third-party libraries needed) | CocoaPods is in maintenance mode; Carthage is effectively deprecated. SPM is the Apple-first standard. HabitX has no anticipated third-party dependencies — the entire stack is Apple frameworks. |

**Third-party dependencies: none anticipated.** The full stack (SwiftUI, SwiftData, WidgetKit, AppIntents, UserNotifications, Swift Charts) is Apple frameworks. Avoid adding external dependencies unless a clear capability gap emerges.

**Confidence:** HIGH

---

## Minimum iOS Deployment Target

**iOS 17.0**

Rationale:
- Interactive WidgetKit widgets (Button/Toggle + AppIntents) require iOS 17+
- SwiftData requires iOS 17+
- `@Observable` macro requires iOS 17+
- `AppIntentTimelineProvider` requires iOS 17+

iOS 17 launched September 2023. As of early 2026, iOS 17+ adoption is well above 90% of active devices. There is no reason to support iOS 16 or earlier given these requirements.

**Confidence:** HIGH

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Persistence | SwiftData | CoreData | CoreData is more capable but adds Obj-C bridge complexity, verbose boilerplate, and worse SwiftUI integration. SwiftData is sufficient for HabitX's simple schema. |
| State management | `@Observable` | ObservableObject + Combine | ObservableObject is the pre-iOS 17 pattern. Coarser re-render granularity, more boilerplate, Combine dependency. Not the 2025 approach. |
| State management | `@Observable` | TCA (The Composable Architecture) | TCA is a third-party dependency justified by large teams and complex state machines. Overkill for a focused habit tracker. |
| UI framework | SwiftUI | UIKit | WidgetKit is SwiftUI-only. Splitting frameworks gains nothing. |
| Testing | Swift Testing | XCTest (unit) | Swift Testing is the declared direction. XCTest for unit tests is legacy-compatible but not the modern approach. |
| Dependencies | Apple frameworks only | Firebase | No backend in v1. Firebase adds dependency weight, analytics overhead, and complicates the v1 simplicity goal. |

---

## Project Setup Checklist

```
Xcode project creation:
[ ] New project: iOS App, SwiftUI interface, Swift language
[ ] Set minimum deployment target: iOS 17.0
[ ] Enable Swift 6 language mode (Build Settings → Swift Language Version → Swift 6)
[ ] Add Widget Extension target
[ ] Set widget extension minimum deployment target: iOS 17.0 (must match app)
[ ] Add App Groups capability to BOTH app and widget extension targets (same group ID)
[ ] Add @Model Swift files to both app and widget extension targets
[ ] Configure ModelContainer with App Group store URL
[ ] Add UserNotifications framework (linked automatically via import)
[ ] Create shared AppGroup identifier: group.com.[bundleid].habitx (or similar)
```

---

## Sources

- Swift 6.1 release: https://www.swift.org/blog/swift-6.1-released/
- Swift 6.2 release: https://www.swift.org/blog/swift-6.2-released/
- What's new in Swift (December 2025): https://www.swift.org/blog/whats-new-in-swift-december-2025/
- App Store SDK requirements (April 2025): https://developer.apple.com/news/upcoming-requirements/?id=02212025a
- Interactive widgets iOS 17 — WWDC23: https://developer.apple.com/videos/play/wwdc2023/10028/
- Migrating SiriKit to AppIntents (WidgetKit): https://developer.apple.com/documentation/widgetkit/migrating-from-sirikit-intents-to-app-intents
- SwiftData meet session — WWDC23: https://developer.apple.com/videos/play/wwdc2023/10187/
- What's new in SwiftData — WWDC24: https://developer.apple.com/videos/play/wwdc2024/10137/
- SwiftData with widgets (Hacking with Swift): https://www.hackingwithswift.com/quick-start/swiftdata/how-to-access-a-swiftdata-container-from-widgets
- SwiftData vs CoreData 2025 comparison: https://byby.dev/swiftdata-or-coredata
- @Observable migration guide (Apple): https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro
- Swift Testing getting started: https://www.polpiella.dev/swift-testing
- Swift 6 strict concurrency (Apple): https://developer.apple.com/documentation/swift/adoptingswift6
- iOS 64 local notification limit: https://developer.apple.com/forums/thread/811171
- App Group + SwiftData forum thread: https://developer.apple.com/forums/thread/789173
