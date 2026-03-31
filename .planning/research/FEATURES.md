# Feature Landscape

**Domain:** Native iOS habit tracking app (widget-first, minimalist)
**Researched:** 2026-03-27
**Confidence:** MEDIUM-HIGH — based on App Store reviews, comparative app analyses, user research aggregators, and psychology literature. Competitor internals (e.g., exact Streaks widget API behavior) are inferred from public sources.

---

## Table Stakes

Features every habit tracker must have. Missing any of these = users leave or leave negative reviews.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Daily habit logging | Core function — the whole point of the app | Low | Boolean tap, count increment, or value entry |
| Streak tracking | Every major competitor has it; users expect visible momentum | Low | Display current streak and longest streak per habit |
| Today view | Users need one consolidated view of what's due today | Low | The main app screen — all habits at current status |
| History / completion log | Users want to see past performance per habit | Low-Med | Calendar or list view; per-habit, scrollable backward |
| Per-habit push notifications | Users rely on reminders; notification failure is a top-cited abandonment reason | Low | Local notifications (no backend needed); user sets time per habit |
| Home screen widget | iOS users expect widget support — cited as table stakes in every 2025/2026 roundup | Med | Multiple sizes; interactive (iOS 17+ AppIntents) |
| Basic stats | Completion rate, streak length, total completions — bare minimum analytics | Low-Med | Per-habit stats view; no need for advanced charts in v1 |
| Add / edit / delete habits | CRUD on habits is assumed; missing edit = early abandonment | Low | Name, type, target, reminder time |
| Dark mode | iOS system feature; users notice when absent | Low | SwiftUI handles most of it automatically |
| Data persistence across launches | Non-negotiable | Low | SwiftData on-device; no data loss on restart |

**Dependency chain:**
```
Habit CRUD → Today View → Widget → Notifications
Habit CRUD → History View → Stats View
```

---

## Differentiators

Features that set the product apart. Users don't leave without them, but they drive positive reviews and word-of-mouth when done well.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Interactive widget (tap-to-complete without opening app) | Streaks is praised specifically for this; it is the entire HabitX value proposition | High | Requires iOS 17+ AppIntents; boolean and count habits only; input habits must open app (iOS widget text-input limitation) |
| Multiple habit types (boolean / count / input) | Most apps are boolean-only; count and input types cover nutrition, hydration, and reps use cases that are otherwise underserved | Med | Three types cover the full space without over-engineering; see PROJECT.md |
| Progress ring / visual completion indicator on widget | Instant at-a-glance status without reading text | Low-Med | Circular progress arc (like Streaks' ring or Apple Watch rings) — strong emotional feedback loop |
| Curated default habits with sensible targets | Onboarding friction killer; users don't have to think about what to track or what target to set | Low | Protein (g) and Water (cups) are natural first choices — concrete, measurable, universal |
| Graceful handling of missed days (non-punitive) | A major complaint about competitors is "streak anxiety" and guilt-loop design; apps that reset streaks harshly get abandoned | Low | Show miss as neutral data point, not a failure state; "best streak" vs "current streak" distinction is enough |
| Per-habit progress ring or bar on Today view in the main app | More granular than a widget but still scannable quickly | Low | Reinforces the same visual language as the widget |
| Widget for each individual habit (dedicated, not combined) | Allows users to place specific habit widgets near relevant contexts (e.g., water widget on kitchen home screen page) | Med | Streaks supports this pattern; per-habit widget configuration |
| Frictionless onboarding (usable in under 2 minutes) | Habit app abandonment spikes in the first session; users who don't log their first habit in session 1 rarely return | Low | First launch should put one default habit on screen, ready to use; defer all configuration |

---

## Anti-Features

Features to explicitly NOT build in v1 — they add complexity, maintenance burden, or undermine the minimalist value proposition.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Social / friends tracking | Requires auth, backend, privacy design, moderation, push infrastructure — entire second product | Defer to v2 milestone; architecture must not block it, but don't build it now |
| Cloud sync / iCloud backup | Tied to account system or iCloud entitlements; adds sync conflict complexity | Use SwiftData local store designed for easy CloudKit migration later |
| Gamification (badges, XP, avatars, levels) | Habitica is the category leader here; HabitX's identity is frictionless simplicity, not games; gamification users already have a home | Explicit non-goal; let streak numbers and completion rings provide intrinsic reward |
| Harsh streak reset / "streak broken" screens | Research shows guilt-loop design drives abandonment; it increases daily opens (good for engagement metrics) but hurts long-term retention | Show missed days as neutral data; preserve "best streak" even when current streak resets |
| Subscription monetization | Top user complaint across all habit apps; Streaks' one-time-purchase model is specifically praised; subscription = churn friction at onboarding | One-time purchase or free with no paywall in v1; decide model before App Store submission |
| Habit categories / tags | Adds a navigation layer that is overkill at small habit counts (3-12 habits); Streaks proves a flat list works up to 24 habits | Keep flat list; add grouping only if user testing proves need |
| Apple Health auto-import | Impressive demo feature; adds HealthKit entitlement review complexity, user permission dialogs, and sync conflict logic for minimal v1 benefit | Defer to v2; the widget logging experience is the differentiator, not passive sync |
| Apple Watch app | Large surface area to build and test; a separate WidgetKit development track | Defer; focus on iPhone widget experience first |
| CSV export / data portability | Power user feature that adds UI surface area; almost zero v1 user need | Add only if user requests come in post-launch |
| Habit templates / marketplace | Community-sourced habit templates require backend, curation, and trust system | Curated defaults (Protein, Water) satisfy discovery need; expand defaults list instead |
| Notification "motivational messages" / coaching copy | Feels condescending to most users; push notification fatigue is real; "just remind me, don't lecture me" is the common request | Use habit name only in notification; e.g., "Time to log your Water" — simple, factual |
| Multiple daily reminders per habit | Notification fatigue; users who get 3 notifications per habit turn off all notifications | One reminder per habit per day is sufficient; if they miss it, that's data |
| Lock screen widgets | Adds another widget configuration surface; secondary to home screen; can add post-launch | Focus home screen widgets; lock screen is additive later |

---

## Feature Dependencies

```
Habit CRUD (add/edit/delete)
  └── Today view (list habits with current state)
       └── Quick-log controls (tap to complete / increment / enter value)
            └── Home screen widget (mirrors today view per-habit)
                 └── Widget interactivity via AppIntents (iOS 17+)
  └── Notifications (per-habit local notification at user time)
  └── History view (per-habit completion log)
       └── Stats view (completion rate, streak, total from history data)
```

Widget interactivity (AppIntents) requires:
- App group container for shared SwiftData access between app and widget extension
- Widget timeline invalidation on state change
- Optimistic UI update pattern (update widget immediately, persist async)

Notifications require:
- UNUserNotificationCenter permission request (do this after first habit is created, not at launch)
- Rescheduling when habit reminder time changes

---

## MVP Recommendation

The minimum lovable product for HabitX 2.0 is:

**Must have at launch:**
1. Habit CRUD (name, type, target, reminder time)
2. Default habits (Protein, Water) available from first launch
3. Today view with quick-log controls for all three habit types
4. Interactive home screen widget per habit (iOS 17+ AppIntents)
5. Per-habit push notifications (local, single daily reminder)
6. History view (calendar or list, scrollable)
7. Stats view (streak, completion rate, total count)
8. Non-punitive missed-day handling

**Defer with confidence:**
- Apple Health integration — impressive but not the differentiator
- Apple Watch — second iOS platform, significant additional scope
- Cloud sync — needed for v2 social features, not v1
- Lock screen widgets — additive, not core
- Gamification of any kind — wrong identity for this product

---

## Competitive Landscape Quick Reference

| App | Core Identity | Widget | Habit Types | Pricing | Strength | Weakness |
|-----|--------------|--------|-------------|---------|----------|---------|
| Streaks | Minimalist, Apple Design Award winner | Excellent, multiple sizes, interactive | Boolean + Health-linked | $4.99 one-time | Best-in-class widget UX, Apple Watch, Health integration | 12-task cap (was 6), no count/input types natively |
| Done (Habit Tracker) | Simple, attractive, stat-forward | Home screen widget | Boolean + frequency goals | Free (3 habits) / paid | Multiple reminders, trends graph, HealthKit | Paywall at 3 habits is aggressive |
| Habitica | Gamified RPG | Minimal | Boolean tasks and dailies | Free / $4.99/month | Social, community, parties | Wrong audience for minimalist users; complex |
| Way of Life | Fast color-coded check-in | Limited | Boolean | One-time ~$5 | Speed of check-in, note-taking | Analytics light; widget experience weak |
| Finch | Emotional, self-care framing | Minimal | Boolean | Free / subscription | Emotional resonance, long-term retention | Not minimalist; different audience entirely |

**HabitX 2.0 opportunity:** Streaks is the closest competitor. The gap is count/input habit types with interactive widgets. Streaks' water tracking is Health-linked (passive) — HabitX's is active logging with an interactive widget counter, which serves users who want manual control over their data.

---

## Psychology of Habit Tracking — Design Implications

Based on BJ Fogg's Behavior Model (B = MAP: Motivation, Ability, Prompt) and category research:

| Principle | Implication for HabitX |
|-----------|------------------------|
| Ability must be maximized | Widget-first is the correct call — every additional tap reduces completion probability |
| Prompt must arrive at the right moment | Per-habit notification at user-chosen time > generic morning/evening blast |
| Celebrate completion immediately | Progress ring completing (filling to 100%) is the micro-celebration; make it satisfying |
| Missed days should be neutral, not punishing | Guilt activates avoidance behavior — users delete the app to escape the guilt |
| Habit loops close with visual feedback | Completion state change must be immediate and visually clear (color, animation) |
| Small habits beat ambitious ones | Curated defaults should start with achievable targets — low bar, high completion rate |

---

## Sources

- [Streaks App Official Site](https://streaksapp.com/) — features, platform support, pricing model
- [The Sweet Setup — Best Habit Tracking App for iOS](https://thesweetsetup.com/apps/best-habit-tracking-app-ios/) — MEDIUM confidence, editorial review
- [Cohorty — Ultimate Guide to Habit Tracker Apps 2025](https://blog.cohorty.app/the-ultimate-guide-to-habit-tracker-apps) — MEDIUM confidence, aggregated analysis
- [Widgetly Blog — 12 Best Habit Tracking Apps 2025](https://www.widgetly.co/blog/best-habit-tracking-apps) — LOW-MEDIUM confidence, marketing blog
- [Done (Habit Tracker) App Store](https://apps.apple.com/us/app/habit-tracker-formerly-done/id1103961876) — feature reference
- [DEV Community — Why Streaks Are Lying to You](https://dev.to/eastkap/why-streaks-are-lying-to-you-and-what-to-track-instead-4hci) — MEDIUM confidence, independent analysis of streak psychology
- [DEV Community — Why Habit Apps Feel Like Nagging Parents](https://dev.to/eastkap/why-habit-apps-feel-like-nagging-parents-and-what-i-built-instead-4jfm) — MEDIUM confidence, guilt-loop pattern analysis
- [DEV Community — iOS Widget Interactivity in 2026](https://dev.to/devin-rosario/ios-widget-interactivity-in-2026-designing-for-the-post-app-era-i17) — MEDIUM confidence, WidgetKit design patterns
- [Apple Developer — Bring widgets to life WWDC23](https://developer.apple.com/videos/play/wwdc2023/10028/) — HIGH confidence, authoritative on AppIntents widget interactivity
- [Psychology Today — The Science Behind Habit Tracking](https://www.psychologytoday.com/us/blog/parenting-from-a-neuroscience-perspective/202512/the-science-behind-habit-tracking) — MEDIUM confidence, behavioral psychology backing
- [BJ Fogg — Behavior Model](https://www.bjfogg.com/learn) — HIGH confidence, foundational habit science
- [Pushwoosh — Push Notification Best Practices 2025](https://www.pushwoosh.com/blog/push-notification-best-practices/) — MEDIUM confidence, notification timing and frequency guidance
- Fhynix.com — Habit Tracker App user research aggregation — LOW-MEDIUM confidence
