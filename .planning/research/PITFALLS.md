# Domain Pitfalls

**Domain:** Native iOS habit tracker — WidgetKit interactive widgets + SwiftData + AppIntents
**Project:** HabitX 2.0
**Researched:** 2026-03-27
**Overall confidence:** HIGH (all findings verified against Apple Developer Forums, official Apple docs, or multiple developer sources)

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or App Store rejection.

---

### Pitfall 1: Skipping VersionedSchema from Day One

**What goes wrong:** When SwiftData models are created without `VersionedSchema`, and any schema change later requires a migration plan, the app crashes on launch for existing users with the error "Cannot use staged migration with an unknown model version." There is no recovery path — SwiftData cannot reconcile an unversioned original with a new versioned schema. The only user-facing fix is deleting the app.

**Why it happens:** SwiftData uses the schema version as a migration anchor. Without an initial `VersionedSchema`, the framework cannot establish where the migration starts from. Apple has not shipped a fix for this in over two years.

**Consequences:** Every user who installed v1 cannot upgrade without losing all data. Complete rewrite of the persistence layer for v2. Possible App Store reviews backlash.

**Prevention:**
- Define a `VersionedSchema` (`SchemaV1`) and `SchemaMigrationPlan` **before shipping any build to TestFlight or the App Store**, even if only one version exists.
- Structure from the start:
  ```swift
  enum HabitSchemaV1: VersionedSchema {
      static var versionIdentifier = Schema.Version(1, 0, 0)
      static var models: [any PersistentModel.Type] { [Habit.self, HabitEntry.self] }
  }
  ```
- Use `ModelContainer(for: schema, migrationPlan: HabitMigrationPlan.self)`.

**Detection:** Any tutorial that uses `@Model` without `VersionedSchema` is showing unproduction-safe code.

**Phase:** Address in Phase 1 (data model setup), before any TestFlight build.

**Sources:** [mertbulan.com — Never use SwiftData without VersionedSchema](https://mertbulan.com/programming/never-use-swiftdata-without-versionedschema), [azamsharp.com — If You Are Not Versioning Your SwiftData Schema](https://azamsharp.com/2026/02/14/if-you-are-not-versioning-your-swiftdata-schema.html), [Apple Developer Forums — SwiftData unversioned migration](https://developer.apple.com/forums/thread/761735)

---

### Pitfall 2: App Groups Not Configured on Both Targets — Widget Reads a Separate Store

**What goes wrong:** The widget extension runs in a separate process. Without an App Group, each process gets its own sandboxed container. The widget creates a brand-new, empty SwiftData store at its own default path. From the widget's perspective, there are no habits — it renders a blank or placeholder state even after the user has set up the app.

**Why it happens:** SwiftData's `ModelContainer` uses `containerURL(forSecurityApplicationGroupIdentifier:)` only when the App Group entitlement is present. If the entitlement is missing from either target, the two processes silently use different file paths. No error is raised.

**Consequences:** Widget appears broken immediately on first use. This is the single most common WidgetKit bug reported on Apple Developer Forums for SwiftData apps.

**Prevention:**
1. In Xcode, add the **App Groups** capability to **both** the main app target and the widget extension target.
2. Use the same group identifier in both (e.g., `group.com.yourname.habitx`).
3. Do not pass a custom `url` to `ModelConfiguration` unless you explicitly point both targets to the same shared container URL:
   ```swift
   let groupURL = FileManager.default.containerURL(
       forSecurityApplicationGroupIdentifier: "group.com.yourname.habitx"
   )!.appending(path: "habits.store")
   let config = ModelConfiguration(url: groupURL)
   ```
4. After adding the entitlement, SwiftData will automatically migrate existing data from the app's private container into the shared group container on next launch.

**Detection warning sign:** Widget shows no data or stale data immediately after first install.

**Phase:** Address in Phase 1 (data model + widget scaffold). Must be done before any widget feature work.

**Sources:** [Apple Developer Forums — SwiftData and correct setup for App Groups](https://developer.apple.com/forums/thread/732986), [HackingWithSwift — How to access a SwiftData container from widgets](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-access-a-swiftdata-container-from-widgets), [Apple Developer Forums — Add App Group to Existing SwiftData](https://developer.apple.com/forums/thread/789173)

---

### Pitfall 3: SwiftData + CloudKit — Non-Optional Attributes Break Sync Silently

**What goes wrong:** CloudKit requires every attribute and every relationship to be optional or have a default value. SwiftData models with non-optional, non-default properties compile fine and work locally, but CloudKit sync will silently fail to activate, or the app will crash at `ModelContainer` initialization when the CloudKit container is specified.

**Why it happens:** CloudKit's schema rules — inherited from Core Data — forbid required fields because records arrive asynchronously and can be partially synced. SwiftData does not surface this constraint loudly at compile time.

**Consequences:** Adding CloudKit in v2 requires going through every model and auditing every field. If mandatory fields exist, you must either make them optional (breaking type safety) or supply defaults. The migration from non-optional to optional is a schema change requiring a new `VersionedSchema` — which compounds Pitfall 1.

**Prevention:** Even in v1 (no CloudKit), design models with future CloudKit in mind:
- All `String` properties: use `= ""` default rather than non-optional with no default.
- All relationships: declare as optional (`[HabitEntry]?` or `var entries: [HabitEntry] = []`).
- Every `Int`/`Double`/`Bool`: provide explicit defaults.

**Detection:** Running `ModelContainer(for:, configurations: ModelConfiguration(cloudKitDatabase: .automatic))` in a test target will surface the errors immediately.

**Phase:** Address in Phase 1. A 10-minute audit of model definitions before shipping v1 prevents a multi-day rewrite for v2.

**Sources:** [HackingWithSwift — Syncing SwiftData with CloudKit](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit), [fatbobman.com — Rules for Adapting Data Models to CloudKit](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/), [Apple Developer Forums — SwiftData CloudKit integration requirements](https://developer.apple.com/forums/thread/735349)

---

### Pitfall 4: SwiftData Custom Migration + CloudKit = Crash

**What goes wrong:** If a `SchemaMigrationPlan` includes any custom (non-lightweight) migration stage, and the `ModelContainer` is configured with a CloudKit database, the app crashes at container initialization. The `willMigrate` and `didMigrate` hooks are never called. This is a confirmed Apple bug present through iOS 17.4 and beyond.

**Why it happens:** SwiftData's CloudKit path bypasses the custom migration execution path. There is no workaround that preserves both custom migration and active CloudKit sync in the same launch.

**Consequences:** Any schema change in v2 that requires data transformation (not just adding optional fields) will be blocked if CloudKit is enabled.

**Prevention:**
- Design v1 models so that all foreseeable schema changes between v1 and v2 are lightweight-compatible (add optional properties, add new models — never rename or remove required fields).
- For v2 schema changes that need custom migration: use the crash-tolerant workaround — attempt `ModelContainer` init with CloudKit, catch the error, fall back to local-only migration, and re-enable CloudKit on next launch.
- Document this limitation in architecture notes so the v2 milestone includes proper planning time.

**Phase:** Understand in Phase 1 to constrain v1 model design. Active mitigation belongs in the future CloudKit milestone.

**Sources:** [Apple Developer Forums — SwiftData with CloudKit failing to migrate schema](https://developer.apple.com/forums/thread/744491), [atomicrobot.com — An Unauthorized Guide to SwiftData Migrations](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)

---

### Pitfall 5: AppIntent `perform()` Not Called When Main App is in Background

**What goes wrong:** If the user taps a widget button (e.g., increment water count) while the main app is open in the background, `perform()` is not called and the widget UI never updates. The system may instead bring the app to the foreground. The widget appears unresponsive.

**Why it happens:** WidgetKit's interactive intent execution depends on process lifecycle. When the main app is running, the system routes the intent through the app process and expects the app to handle it, but the routing can fail if the widget extension and the app process are competing for the intent.

**Additional variant:** If the user taps the widget button multiple times quickly (before the previous re-render completes), subsequent taps open the app rather than calling `perform()`.

**iOS 18.4 change:** Apple introduced stricter sandboxing for widget AppIntents — the workaround is to conform to `ForegroundContinuableIntent` to force execution in the main app context, while keeping `openAppWhenRun = false`.

**Consequences:** Core UX flow (increment from widget) becomes unreliable in real-world use. Testing on Simulator does not reproduce this — only physical devices.

**Prevention:**
- Test on physical devices throughout development, never rely solely on Simulator for AppIntent testing.
- For iOS 18.4+: evaluate `ForegroundContinuableIntent` conformance for count-increment and toggle intents.
- Keep intent `perform()` fast and synchronous wherever possible; save the SwiftData context before returning.
- Call `WidgetCenter.shared.reloadAllTimelines()` at the end of `perform()`.

**Detection:** Tap widget button while app is backgrounded on a real device — if widget doesn't update, this pitfall applies.

**Phase:** Phase 2 (interactive widgets). Must be verified on device before calling the phase complete.

**Sources:** [Apple Developer Forums — Why don't interactive buttons call perform](https://developer.apple.com/forums/thread/732771), [Apple Developer Forums — How to prevent interactive widgets from opening app](https://developer.apple.com/forums/thread/733102), [dev.to — iOS Widget Interactivity in 2026](https://dev.to/devin-rosario/ios-widget-interactivity-in-2026-designing-for-the-post-app-era-i17)

---

## Moderate Pitfalls

---

### Pitfall 6: Widget Timeline Not Refreshing Immediately After AppIntent

**What goes wrong:** After `perform()` calls `WidgetCenter.shared.reloadAllTimelines()`, the widget does not update right away on physical devices. The delay can range from a few seconds to several minutes. This is a known Apple issue (FB11522170). The widget continues displaying the pre-tap state, which is particularly visible for count habits (water: tapped to add a cup, counter still shows old value).

**Why it happens:** `reloadAllTimelines()` is advisory. The system batches reload requests and honors them based on device conditions, power state, and widget budget. AppIntent execution runs in a background scene with lower priority.

**Prevention:**
- Use **invalidating entry** pattern: WidgetKit supports returning a current entry optimistically in the timeline alongside future entries. The widget can use placeholder/animated state during the refresh window.
- Do not call `DispatchQueue.main.asyncAfter` to delay the reload — this is unreliable on device and will drain the daily update budget.
- The system will eventually refresh. Design the widget UI so a 5-10 second stale display is acceptable (a subtle activity indicator can help).
- On iOS 17+, widgets that use AppIntents automatically get an "invalidating entry" from the system — verify this is configured correctly.

**Detection:** On a physical device: tap increment, observe widget; if the counter doesn't update within 1-2 seconds, the standard behavior is in play.

**Phase:** Phase 2 (interactive widgets). Design for this delay in the widget UX — do not try to fight it.

**Sources:** [GitHub feedback — FB11522170 reloading widget timeline does not reload immediately](https://github.com/feedback-assistant/reports/issues/359), [Apple Developer Forums — Widget AppIntent updates SwiftData](https://developer.apple.com/forums/thread/739741), [swiftsenpai.com — How to Update or Refresh a Widget](https://swiftsenpai.com/development/refreshing-widget/)

---

### Pitfall 7: ModelContext In-Memory Staleness After Widget Writes

**What goes wrong:** When a widget's `AppIntent` writes to the shared SwiftData store, the main app's `ModelContext` in-memory cache does not automatically reflect the new data. On iOS 17, fetching from the main app's context still returns stale data even after the widget has committed changes. `@Query`-driven SwiftUI views do not update.

**Why it happens:** Each process (main app, widget extension) holds its own `ModelContainer`/`ModelContext` instance. Writing through the widget's context commits to the SQLite file, but the main app's context does not observe file-level changes in real time. iOS 18 improved this, but it is not guaranteed to be immediate.

**Prevention:**
- Always call `modelContext.save()` in the widget's `perform()` before returning.
- In the main app, call `modelContext.refresh(object, mergeChanges: true)` or trigger a re-fetch when the app becomes active (use `scenePhase` observation in SwiftUI).
- For the Today view: fetch habits fresh on `.onAppear` and on `scenePhase == .active` transitions — do not rely on passive `@Query` observation alone for correctness on iOS 17.

**Detection:** Write from widget, then bring main app to foreground — if values are stale, this pitfall is active.

**Phase:** Phase 2 (interactive widgets) + Phase 3 (Today view). Test the sync round-trip explicitly.

**Sources:** [Apple Developer Forums — Syncing changes between main app and extension](https://developer.apple.com/forums/thread/764290), [Apple Developer Forums — SwiftData updates delay in widget](https://developer.apple.com/forums/thread/760621)

---

### Pitfall 8: Widget Memory Limit — 30 MB Hard Cap

**What goes wrong:** Widget extensions are killed by the OS (Jetsam) when they exceed ~30 MB of memory. This surfaces as the widget rendering a grey placeholder or blank view on physical devices with no crash log surfaced to the developer. Images are the primary trigger, but loading a large SwiftData store can also breach the limit.

**Why it happens:** Widgets run in a constrained process with a hard memory budget enforced by the OS. The Simulator does not enforce this cap, so the issue only appears on real devices.

**Prevention:**
- Keep widget views pure display code — no lazy loading, no large image assets, no computed statistics.
- For habit progress rings or icons: use vector SF Symbols, not bitmap images.
- Pre-compute all values (streak count, progress percentage, today's total) in the main app and cache them in a lightweight UserDefaults key for the widget to read, rather than querying SwiftData in `getTimeline`.
- Profile with Instruments' Memory template on a physical device before each phase completion.

**Detection:** Widget shows grey box on physical device but works in Simulator = memory pressure.

**Phase:** Relevant from Phase 1 (widget scaffold). Build with this constraint in mind from the first widget implementation.

**Sources:** [GitHub feedback — FB8832751: 30 MB memory limit for widgets](https://github.com/feedback-assistant/reports/issues/177), [Apple Developer Forums — WidgetKit memory limit and CoreData](https://developer.apple.com/forums/thread/732781)

---

### Pitfall 9: iOS Local Notification Hard Limit of 64 Scheduled Notifications

**What goes wrong:** iOS silently discards any scheduled local notification beyond the 64 most recently-scheduled ones. For HabitX, each habit has a daily repeating notification. With a `UNCalendarNotificationTrigger` using `repeats: true`, each habit only consumes 1 notification slot. However, if you schedule individual notifications per-day instead of repeating triggers, a user with 5 habits and 30 days pre-scheduled would need 150 slots — hitting the cap and losing future notifications silently.

**Why it happens:** iOS imposes a 64-notification cap per app. Exceeding it causes the system to keep only the soonest-firing 64, discarding the rest without any error or callback.

**Prevention:**
- Use `UNCalendarNotificationTrigger` with `repeats: true` for daily habit reminders — this uses one slot per habit, not one per day.
- If more complex scheduling is ever needed (e.g., different times per day of week), implement a notification scheduler that periodically re-evaluates and re-schedules from `applicationDidBecomeActive`.
- Always check `UNUserNotificationCenter.current().pendingNotificationRequests(completionHandler:)` when debugging missing notifications.

**Detection:** More than 64 pending notification requests found via `pendingNotificationRequests` = over-scheduling.

**Phase:** Phase 3 (notifications). Use repeating triggers from the start.

**Sources:** [doist.dev — Implementing a local notification scheduler in Todoist iOS](https://www.doist.dev/implementing-a-local-notification-scheduler-in-todoist-ios/), [Apple Developer Forums — Local Notifications Limit Workaround](https://developer.apple.com/forums/thread/106829)

---

### Pitfall 10: "Today" Date Boundary — Timezone and Midnight Rollover Edge Cases

**What goes wrong:** Determining whether a habit belongs to "today" using `Date()` comparisons without calendar-aware boundaries causes bugs when:
1. The user is in a timezone that observes DST — some days are 23 or 25 hours long, so "midnight + 24h" is wrong.
2. The user travels across timezones — a habit logged at 11 PM ET appears as "yesterday" after flying to PT.
3. A statically cached `Calendar.current` reference is used — if the device timezone changes while the app is running, the cached calendar doesn't update its timezone for date component calculations.

**Why it happens:** `Date` values are absolute UTC instants. "Today" is a user-local concept defined by `Calendar.startOfDay(for:)` with the current timezone. Developers often compute boundaries with arithmetic (`Date() - 86400`) rather than calendar APIs.

**Prevention:**
- Always use `Calendar.current.startOfDay(for: Date())` and `Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!` to compute today's window.
- Never store or cache a `Calendar` instance as a `static let` — access `Calendar.current` fresh at the call site so timezone changes are reflected.
- For the widget timeline, generate entries anchored to `startOfDay` boundaries so the widget naturally transitions at local midnight.
- Test by setting the device to a half-hour offset timezone (e.g., India Standard Time, UTC+5:30) and verify streak logic holds.

**Detection:** Streak count off by one after crossing midnight, or habit marked complete on wrong day after timezone change.

**Phase:** Phase 1 (data model) for the boundary logic. Phase 2 (widget timeline) for the rollover entry generation.

**Sources:** [radu-ionut-dan.medium.com — iOS calendars current vs autoupdatingCurrent](https://radu-ionut-dan.medium.com/ios-calendars-current-vs-autoupdatingcurrent-3581635684ad), [swiftbysundell.com — Computing dates in Swift](https://www.swiftbysundell.com/articles/computing-dates-in-swift/)

---

### Pitfall 11: Widget Daily Update Budget Exhaustion

**What goes wrong:** A frequently viewed widget gets approximately 40–70 system-triggered refreshes per day. Using `DispatchQueue.main.asyncAfter` to schedule additional refreshes, or calling `reloadAllTimelines()` repeatedly in a loop, drains this budget. Once exhausted, the widget stops refreshing at all — even for legitimate updates like midnight rollover.

**Why it happens:** WidgetKit tracks each app's timeline reload budget. Programmatic calls made inside `perform()` are counted against this budget alongside system-scheduled refreshes.

**Additional gotcha:** Timeline `ReloadPolicy.atEnd` and `.after(date:)` are not honored exactly. The system may wait an additional 5–60 minutes beyond the requested time.

**Prevention:**
- Call `WidgetCenter.shared.reloadAllTimelines()` at most once per user action (once in `perform()`, once when app returns to foreground).
- Schedule timeline entries at midnight boundaries using date math so the system handles the daily rollover without a programmatic reload.
- Never use `asyncAfter` within an AppIntent to schedule a delayed reload.
- In the `TimelineProvider`, return a `.after(nextMidnight)` policy so the system handles the day transition naturally.

**Phase:** Phase 2 (widget timeline design). The timeline entry structure should be designed with the budget in mind from the start.

**Sources:** [developer.apple.com — Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date), [swiftsenpai.com — How to Update or Refresh a Widget](https://swiftsenpai.com/development/refreshing-widget/), [medium.com — Understanding the Limitations of Widgets Runtime](https://medium.com/@telawittig/understanding-the-limitations-of-widgets-runtime-in-ios-app-development-and-strategies-for-managing-a3bb018b9f5a)

---

## Minor Pitfalls

---

### Pitfall 12: User Notification Authorization Not Re-checked on Foreground

**What goes wrong:** Users can revoke notification permission in Settings at any time. An app that only checks authorization at first-launch permission request will continue attempting to schedule notifications silently — no error is thrown, but notifications never fire. The habit reminder feature appears broken.

**Prevention:**
- Check `UNUserNotificationCenter.current().getNotificationSettings(completionHandler:)` each time the app enters the foreground (`scenePhase == .active`).
- Conditionally show an in-app prompt or settings link if authorization is `.denied` and the user has reminders configured.
- Use `UNAuthorizationStatus.provisional` carefully — provisional authorization does not present system alerts; notifications are delivered quietly to the Notification Center only.

**Phase:** Phase 3 (notifications). Add foreground authorization check as part of the notification feature.

**Sources:** [developer.apple.com — UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter), [nilcoalescing.com — Trial Notifications with Provisional Authorization](https://nilcoalescing.com/blog/TrialNotificationsWithProvisionalAuthorizationOnIOS/)

---

### Pitfall 13: Xcode Entitlement Mismatch Between Debug and Release Provisioning Profiles

**What goes wrong:** App Groups added via Xcode's automatic signing work in Debug builds but fail in Release builds (or TestFlight) when provisioning profiles are not regenerated. The widget silently loses access to the shared container in production.

**Why it happens:** Xcode's automatic provisioning generates separate profiles per target. Adding App Groups capability updates the profile for the currently active scheme, but the Release profile may be stale or the widget target's profile may not include the same group identifier.

**Prevention:**
- After adding or modifying App Groups, go to Apple Developer portal and verify the App Group is listed under both App IDs (main app and widget extension).
- Run a TestFlight build and verify widget functionality before marking any phase complete — don't only test in Debug mode.
- If using manual signing, manually regenerate all provisioning profiles after capability changes.

**Detection:** Widget works in Debug on device, but is blank or crashes in TestFlight.

**Phase:** Phase 1 (initial project setup). Include a TestFlight smoke test of widget data access before the end of Phase 1.

**Sources:** [developer.apple.com — Configuring app groups](https://developer.apple.com/documentation/Xcode/configuring-app-groups), [useyourloaf.com — Sharing data with a Widget](https://useyourloaf.com/blog/sharing-data-with-a-widget/)

---

### Pitfall 14: Privacy Manifest Missing for App Store Submission

**What goes wrong:** As of 2025, Apple requires a `PrivacyInfo.xcprivacy` manifest in any app that uses certain "required reason APIs." Local notifications, UserDefaults, and file access APIs may require declared reasons. Missing or incomplete manifests result in App Store rejection.

**Why it happens:** Apple's Privacy Manifest requirement was expanded in 2024 and strictly enforced from 2025. SDK-level manifest requirements were added for any SDK included as a dependency.

**Prevention:**
- Add `PrivacyInfo.xcprivacy` to the main app target and the widget extension target.
- Declare all NSPrivacyAccessedAPITypes with appropriate reason codes.
- For UserDefaults accessed via App Groups shared suiteName: include the `NSUserDefaults` reason code.
- Review App Store Connect for any privacy manifest warnings after uploading builds — warnings now precede rejection.

**Phase:** Phase 4 or the final pre-submission phase. Add to the definition of done for any release build.

**Sources:** [nextnative.dev — App Store Review Guidelines 2025: Checklist + Rejection Reasons](https://nextnative.dev/blog/app-store-review-guidelines), [secureprivacy.ai — Mobile App Consent for iOS 2025](https://secureprivacy.ai/blog/mobile-app-consent-ios-2025)

---

### Pitfall 15: Text Input Is Not Possible Inside a Widget

**What goes wrong:** Developers new to WidgetKit sometimes attempt to add text fields or number entry to widgets. This is not possible — WidgetKit only supports `Button` and `Toggle` with AppIntents for interactivity. Any attempt to use `.textFieldStyle`, `TextField`, or numeric steppers will be silently ignored or cause a compile error in the widget extension context.

**Prevention:**
- For input habits (protein): the widget must show the current total and a button that opens the main app to a logging sheet via a `Link` or `widgetURL`.
- Design the app-open flow to deep-link directly to the logging view for that specific habit to preserve the low-friction experience.
- This constraint is already acknowledged in the PROJECT.md — just ensure implementation does not attempt widget text input.

**Phase:** Phase 1 (widget scaffold design). The widget information architecture must be finalized before implementation to avoid rework.

**Sources:** [developer.apple.com — Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities), [PROJECT.md constraints section]

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1: SwiftData model design | No VersionedSchema from start → migration crash in v2 | Define SchemaV1 and SchemaMigrationPlan before first TestFlight |
| Phase 1: SwiftData model design | Non-optional fields block future CloudKit | Add default values to all properties at model creation time |
| Phase 1: App Groups + widget scaffold | Widget reads separate empty store | Add App Groups entitlement to both targets, verify with explicit data read test |
| Phase 1: Xcode project setup | Debug entitlements diverge from Release | Run TestFlight smoke test on widget data read before phase sign-off |
| Phase 2: Interactive widget buttons | perform() not fired with app backgrounded | Test on physical device, evaluate ForegroundContinuableIntent for iOS 18.4+ |
| Phase 2: Interactive widget timeline | Widget shows stale state after tap | Design widget UI to tolerate 5-10 second refresh delay; use invalidating entry pattern |
| Phase 2: Widget timeline generation | Midnight rollover missing or off by one | Anchor entries to Calendar.current.startOfDay boundaries, not arithmetic offsets |
| Phase 2: ModelContext staleness | Main app Today view shows stale data after widget write | Refresh context on scenePhase .active |
| Phase 2: Update budget | Excessive reloadAllTimelines calls drain daily budget | Single reload per user action; rely on system schedule for day boundaries |
| Phase 2: Widget memory | Widget blanks out on physical device under memory pressure | Stay under 30 MB; profile with Instruments on device |
| Phase 3: Notifications | Missing reminders after user revokes permission | Check auth status on every foreground transition |
| Phase 3: Notifications | Over-scheduling blows 64-notification cap | Use repeating triggers (one slot per habit) |
| Pre-submission | App Store rejection for missing PrivacyInfo.xcprivacy | Add manifests to both targets before first submission |
| v2 CloudKit milestone | Custom migration plan crashes with CloudKit container | Plan lightweight-only migrations; use CloudKit fallback workaround for custom stages |

---

## Sources (Consolidated)

- [Apple Developer Documentation — WidgetKit](https://developer.apple.com/documentation/widgetkit)
- [Apple Developer Documentation — Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- [Apple Developer Documentation — Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
- [Apple Developer Documentation — UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Apple Developer Documentation — Configuring app groups](https://developer.apple.com/documentation/Xcode/configuring-app-groups)
- [Apple Developer Forums — SwiftData and correct setup for App Groups](https://developer.apple.com/forums/thread/732986)
- [Apple Developer Forums — Add App Group to Existing SwiftData](https://developer.apple.com/forums/thread/789173)
- [Apple Developer Forums — Syncing changes between main app and extension](https://developer.apple.com/forums/thread/764290)
- [Apple Developer Forums — SwiftData updates delay in widget](https://developer.apple.com/forums/thread/760621)
- [Apple Developer Forums — Widget AppIntent updates SwiftData](https://developer.apple.com/forums/thread/739741)
- [Apple Developer Forums — SwiftData with CloudKit failing to migrate schema](https://developer.apple.com/forums/thread/744491)
- [Apple Developer Forums — SwiftData CloudKit integration requirements](https://developer.apple.com/forums/thread/735349)
- [Apple Developer Forums — Why don't interactive buttons call perform](https://developer.apple.com/forums/thread/732771)
- [Apple Developer Forums — How to prevent interactive widgets from opening app](https://developer.apple.com/forums/thread/733102)
- [Apple Developer Forums — SwiftData unversioned migration](https://developer.apple.com/forums/thread/761735)
- [Apple Developer Forums — Local Notifications Limit Workaround](https://developer.apple.com/forums/thread/106829)
- [HackingWithSwift — How to access a SwiftData container from widgets](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-access-a-swiftdata-container-from-widgets)
- [HackingWithSwift — Syncing SwiftData with CloudKit](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit)
- [mertbulan.com — Never use SwiftData without VersionedSchema](https://mertbulan.com/programming/never-use-swiftdata-without-versionedschema)
- [azamsharp.com — If You Are Not Versioning Your SwiftData Schema](https://azamsharp.com/2026/02/14/if-you-are-not-versioning-your-swiftdata-schema.html)
- [atomicrobot.com — An Unauthorized Guide to SwiftData Migrations](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)
- [fatbobman.com — Rules for Adapting Data Models to CloudKit](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
- [GitHub feedback — FB11522170 reloading widget timeline does not reload immediately](https://github.com/feedback-assistant/reports/issues/359)
- [GitHub feedback — FB8832751: 30 MB memory limit for widgets](https://github.com/feedback-assistant/reports/issues/177)
- [doist.dev — Implementing a local notification scheduler in Todoist iOS](https://www.doist.dev/implementing-a-local-notification-scheduler-in-todoist-ios/)
- [useyourloaf.com — Sharing data with a Widget](https://useyourloaf.com/blog/sharing-data-with-a-widget/)
- [swiftsenpai.com — How to Update or Refresh a Widget](https://swiftsenpai.com/development/refreshing-widget/)
- [radu-ionut-dan.medium.com — iOS calendars current vs autoupdatingCurrent](https://radu-ionut-dan.medium.com/ios-calendars-current-vs-autoupdatingcurrent-3581635684ad)
- [swiftbysundell.com — Computing dates in Swift](https://www.swiftbysundell.com/articles/computing-dates-in-swift/)
- [nextnative.dev — App Store Review Guidelines 2025](https://nextnative.dev/blog/app-store-review-guidelines)
- [nilcoalescing.com — Trial Notifications with Provisional Authorization](https://nilcoalescing.com/blog/TrialNotificationsWithProvisionalAuthorizationOnIOS/)
- [medium.com — Understanding the Limitations of Widgets Runtime](https://medium.com/@telawittig/understanding-the-limitations-of-widgets-runtime-in-ios-app-development-and-strategies-for-managing-a3bb018b9f5a)
- [dev.to — iOS Widget Interactivity in 2026](https://dev.to/devin-rosario/ios-widget-interactivity-in-2026-designing-for-the-post-app-era-i17)
