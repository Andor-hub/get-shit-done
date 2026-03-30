import Foundation

/// Sendable value type that captures everything a widget view needs to render
/// a single habit's current state. Created from a SwiftData Habit model on the
/// main actor, then safely passed into the widget's timeline entry (Sendable context).
struct HabitSnapshot: Sendable {
    let id: UUID
    let name: String
    let habitType: HabitType
    let unit: String
    let dailyTarget: Double
    let todayValue: Double
    let isCompleted: Bool

    init(habit: HabitSchemaV1.Habit) {
        id = habit.id
        name = habit.name
        habitType = HabitType(rawValue: habit.habitType) ?? .boolean
        unit = habit.unit
        dailyTarget = habit.dailyTarget

        // Inline the same logic as HabitLogService.todayValue/isCompleted.
        // HabitLogService is in HabitX/HabitX/Services which is added to the
        // widget target in Task 2 (project.yml update). Inlining here avoids
        // a build-order dependency for Task 1 verification while keeping the
        // same logic in one place for the future widget timeline provider.
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
        let value: Double
        if let tomorrow {
            value = habit.logs
                .filter { $0.date >= today && $0.date < tomorrow }
                .reduce(0) { $0 + $1.value }
        } else {
            value = 0
        }
        todayValue = value
        isCompleted = value >= habit.dailyTarget
    }
}
