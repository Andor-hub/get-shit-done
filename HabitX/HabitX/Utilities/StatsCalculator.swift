import Foundation

/// Pure functions for computing habit streaks and completion stats.
/// No ModelContext dependency — only reads Habit.logs and Habit.dailyTarget.
enum StatsCalculator {

    // MARK: - Streak Computation

    /// Returns the current consecutive-day streak for a habit.
    ///
    /// Rules:
    /// - If today is completed, count from today backward.
    /// - If today is NOT completed, count from yesterday backward.
    /// - If yesterday is also incomplete, return 0.
    static func currentStreak(for habit: HabitSchemaV1.Habit) -> Int {
        let completedDays = completedDaySet(for: habit)
        guard !completedDays.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Determine starting point: today if completed, yesterday otherwise
        let startDay: Date
        if completedDays.contains(today) {
            startDay = today
        } else {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  completedDays.contains(yesterday) else {
                return 0
            }
            startDay = yesterday
        }

        // Walk backward counting consecutive days
        var streak = 0
        var current = startDay
        while completedDays.contains(current) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }
        return streak
    }

    /// Returns the longest consecutive completed-day run across all history.
    static func bestStreak(for habit: HabitSchemaV1.Habit) -> Int {
        let completedDays = completedDaySet(for: habit)
        guard !completedDays.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedDays = completedDays.sorted()

        var best = 1
        var current = 1

        for i in 1..<sortedDays.count {
            let previous = sortedDays[i - 1]
            let day = sortedDays[i]
            if let expectedNext = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(expectedNext, inSameDayAs: day) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    // MARK: - Completion Rate

    /// Returns the fraction of the last 30 calendar days on which the habit was completed.
    /// Returns 0.0 when no logs exist, 1.0 when all 30 days complete.
    static func completionRate30Days(for habit: HabitSchemaV1.Habit) -> Double {
        completionRate(for: habit, days: 30)
    }

    /// Returns the fraction of the last `days` calendar days on which the habit was completed.
    static func completionRate(for habit: HabitSchemaV1.Habit, days: Int) -> Double {
        guard days > 0 else { return 0.0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return 0.0
        }
        let completedDays = completedDaySet(for: habit)
        var count = 0
        var current = startDate
        while current <= today {
            if completedDays.contains(current) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return Double(count) / Double(days)
    }

    // MARK: - Chart Data

    /// Returns the last `days` calendar days with a bool indicating whether each was completed.
    /// Index 0 is the oldest day; the last index is today.
    static func completionByDay(
        for habit: HabitSchemaV1.Habit,
        days: Int
    ) -> [(date: Date, completed: Bool)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let completedDays = completedDaySet(for: habit)

        return (0..<days).compactMap { offset -> (Date, Bool)? in
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) else {
                return nil
            }
            return (date, completedDays.contains(date))
        }
    }

    // MARK: - Private Helpers

    /// Builds a Set of startOfDay Dates where the habit was completed (value >= dailyTarget).
    private static func completedDaySet(for habit: HabitSchemaV1.Habit) -> Set<Date> {
        let calendar = Calendar.current
        // Group log values by startOfDay
        var valuesByDay: [Date: Double] = [:]
        for log in habit.logs {
            let day = calendar.startOfDay(for: log.date)
            valuesByDay[day, default: 0] += log.value
        }
        // Keep only days where total >= dailyTarget
        return Set(valuesByDay.compactMap { day, total in
            total >= habit.dailyTarget ? day : nil
        })
    }
}
