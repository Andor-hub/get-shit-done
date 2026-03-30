import SwiftUI

/// A value-type template for creating pre-configured Habit instances.
struct HabitTemplate: Sendable {
    let name: String
    let habitType: HabitType
    let dailyTarget: Double
    let unit: String
}

extension HabitTemplate {
    static let proteinTemplate = HabitTemplate(
        name: "Protein",
        habitType: .input,
        dailyTarget: 150.0,
        unit: "g"
    )

    static let waterTemplate = HabitTemplate(
        name: "Water",
        habitType: .count,
        dailyTarget: 8.0,
        unit: "cups"
    )

    /// The default habits surfaced during first-launch onboarding.
    static let defaultHabits: [HabitTemplate] = [proteinTemplate, waterTemplate]
}

/// Creates a new HabitSchemaV1.Habit from a template.
/// The caller is responsible for inserting the returned instance into the ModelContext.
func createHabit(from template: HabitTemplate, sortOrder: Int) -> HabitSchemaV1.Habit {
    let habit = HabitSchemaV1.Habit()
    habit.name = template.name
    habit.habitType = template.habitType.rawValue
    habit.dailyTarget = template.dailyTarget
    habit.unit = template.unit
    habit.sortOrder = sortOrder
    return habit
}

// MARK: - App Accent Color

extension Color {
    /// Calm teal accent color; works in both light and dark mode (D-12).
    static let appAccent = Color(red: 0.0, green: 0.6, blue: 0.7)
}
