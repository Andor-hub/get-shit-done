import Foundation
import SwiftData

/// Service for all write operations on HabitLog records.
/// Functions that mutate ModelContext are @MainActor since ModelContext is not Sendable.
enum HabitLogService {

    // MARK: - Write Operations

    /// Toggles a boolean habit: deletes today's log if it exists, or creates one with value=1.
    @MainActor
    static func toggleBoolean(
        habit: HabitSchemaV1.Habit,
        context: ModelContext
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = todayLog(for: habit, startOfDay: today) {
            context.delete(existing)
        } else {
            let log = HabitSchemaV1.HabitLog()
            log.date = today
            log.value = 1.0
            log.habit = habit
            context.insert(log)
        }
    }

    /// Increments a count habit: adds 1.0 to today's log value, or creates a log with value=1.
    @MainActor
    static func incrementCount(
        habit: HabitSchemaV1.Habit,
        context: ModelContext
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = todayLog(for: habit, startOfDay: today) {
            existing.value += 1.0
            existing.loggedAt = Date()
        } else {
            let log = HabitSchemaV1.HabitLog()
            log.date = today
            log.value = 1.0
            log.habit = habit
            context.insert(log)
        }
    }

    /// Sets a specific value for an input habit today, replacing any existing value.
    @MainActor
    static func setValue(
        habit: HabitSchemaV1.Habit,
        value: Double,
        context: ModelContext
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = todayLog(for: habit, startOfDay: today) {
            existing.value = value
            existing.loggedAt = Date()
        } else {
            let log = HabitSchemaV1.HabitLog()
            log.date = today
            log.value = value
            log.habit = habit
            context.insert(log)
        }
    }

    // MARK: - Read Helpers (no ModelContext needed)

    /// Returns the sum of all log values for today. Returns 0 if no log exists.
    static func todayValue(for habit: HabitSchemaV1.Habit) -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
            return 0
        }
        return habit.logs
            .filter { $0.date >= today && $0.date < tomorrow }
            .reduce(0) { $0 + $1.value }
    }

    /// Returns true if today's logged value meets or exceeds the daily target.
    static func isCompleted(habit: HabitSchemaV1.Habit) -> Bool {
        todayValue(for: habit) >= habit.dailyTarget
    }

    // MARK: - Private Helpers

    /// Finds today's single log using the startOfDay boundary. Returns nil if none exists.
    private static func todayLog(
        for habit: HabitSchemaV1.Habit,
        startOfDay: Date
    ) -> HabitSchemaV1.HabitLog? {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }
        return habit.logs.first { $0.date >= startOfDay && $0.date < tomorrow }
    }
}
