import SwiftData

enum HabitSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Habit.self, HabitLog.self]
    }
}

extension HabitSchemaV1 {
    @Model
    final class Habit {
        var id: UUID = UUID()
        var name: String = ""
        var habitType: String = "boolean"
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

enum HabitType: String, CaseIterable, Sendable {
    case boolean
    case count
    case input
}
