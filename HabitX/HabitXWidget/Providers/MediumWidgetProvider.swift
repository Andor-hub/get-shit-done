import WidgetKit
import SwiftUI
import SwiftData

/// TimelineProvider for the medium (all-habits) widget.
/// Uses StaticConfiguration (no per-widget configuration needed — always shows all habits).
///
/// Swift 6 note: TimelineProvider's completion callbacks are not @Sendable, so we use
/// @preconcurrency conformance to suppress the strict concurrency warning, which is acceptable
/// because WidgetKit guarantees the callbacks are called before the provider is deallocated.
struct MediumWidgetProvider: @preconcurrency TimelineProvider {
    typealias Entry = MediumWidgetEntry

    func placeholder(in context: Context) -> MediumWidgetEntry {
        MediumWidgetEntry(date: .now, snapshots: [])
    }

    @MainActor
    func getSnapshot(in context: Context, completion: @escaping (MediumWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    @MainActor
    func getTimeline(in context: Context, completion: @escaping (Timeline<MediumWidgetEntry>) -> Void) {
        let entry = makeEntry()

        // Refresh at midnight so habits reset daily
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: .now)
        ) ?? Calendar.current.startOfDay(for: .now)

        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    /// Fetches all habits from SwiftData and builds a timeline entry.
    /// Must run on MainActor because ModelContainer.mainContext is MainActor-isolated.
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
