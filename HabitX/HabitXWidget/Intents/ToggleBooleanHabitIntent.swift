import AppIntents
import SwiftData
import WidgetKit
import Foundation

/// AppIntent that toggles a boolean habit's completion state for today.
/// Called from interactive widget buttons. Writes to the shared SwiftData container
/// and reloads widget timelines so the UI reflects the new state immediately.
struct ToggleBooleanHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Habit"

    /// UUID of the habit to toggle, passed as a String because AppIntent
    /// @Parameter does not support UUID directly.
    @Parameter(title: "Habit ID")
    var habitId: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = ModelContext(SharedModelContainer.container)
        let idStr = habitId

        let descriptor = FetchDescriptor<HabitSchemaV1.Habit>(
            predicate: #Predicate { $0.id.uuidString == idStr }
        )
        guard let habit = try context.fetch(descriptor).first else {
            return .result()
        }

        let today = Calendar.current.startOfDay(for: Date())
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
            return .result()
        }

        if let existing = habit.logs.first(where: { $0.date >= today && $0.date < tomorrow }) {
            context.delete(existing)
        } else {
            let log = HabitSchemaV1.HabitLog()
            log.date = today
            log.value = 1.0
            log.habit = habit
            context.insert(log)
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
