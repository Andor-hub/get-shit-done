import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

/// AppIntentTimelineProvider for the small (single-habit) widget.
/// Uses HabitWidgetIntent to configure which habit to display.
///
/// Per plan: uses FetchDescriptor (not @Query) for data fetching,
/// @MainActor for mainContext access, midnight refresh policy for daily reset.
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

        // Refresh at midnight so habits reset daily
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: .now)
        ) ?? Calendar.current.startOfDay(for: .now)

        return Timeline(entries: [entry], policy: .after(tomorrow))
    }

    /// Fetches the habit from SwiftData and builds a timeline entry.
    /// Must run on MainActor because ModelContainer.mainContext is MainActor-isolated.
    @MainActor
    private func makeEntry(for entity: HabitEntity?) -> HabitWidgetEntry {
        guard let entity else {
            return HabitWidgetEntry(date: .now, habitSnapshot: nil)
        }

        let context = SharedModelContainer.container.mainContext
        let id = entity.id
        let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
            predicate: #Predicate { $0.id == id }
        )

        guard let habit = (try? context.fetch(descriptor))?.first else {
            return HabitWidgetEntry(date: .now, habitSnapshot: nil)
        }

        return HabitWidgetEntry(date: .now, habitSnapshot: HabitSnapshot(habit: habit))
    }
}
