import AppIntents
import SwiftData
import Foundation

/// EntityQuery that fetches Habit records from the shared SwiftData container.
/// Used to populate the habit picker in HabitWidgetIntent's configuration UI.
struct HabitEntityQuery: EntityQuery {

    /// Returns all habits sorted by sortOrder — used to populate the picker list.
    @MainActor
    func suggestedEntities() async throws -> [HabitEntity] {
        let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let habits = try SharedModelContainer.container.mainContext.fetch(descriptor)
        return habits.map { habit in
            HabitEntity(
                id: habit.id,
                name: habit.name,
                habitType: habit.habitType,
                unit: habit.unit
            )
        }
    }

    /// Returns entities matching the given UUIDs — called when a previously selected habit
    /// needs to be resolved from its stored identifier.
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        let ids = identifiers
        let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let habits = try SharedModelContainer.container.mainContext.fetch(descriptor)
        return habits.map { habit in
            HabitEntity(
                id: habit.id,
                name: habit.name,
                habitType: habit.habitType,
                unit: habit.unit
            )
        }
    }
}
