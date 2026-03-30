import Testing
import Foundation
@testable import HabitX

// MARK: - Test Helpers

private func makeHabit(dailyTarget: Double = 1.0) -> HabitSchemaV1.Habit {
    let habit = HabitSchemaV1.Habit()
    habit.dailyTarget = dailyTarget
    habit.habitType = HabitType.boolean.rawValue
    return habit
}

private func addLog(
    to habit: HabitSchemaV1.Habit,
    daysAgo: Int,
    value: Double = 1.0
) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return }
    let log = HabitSchemaV1.HabitLog()
    log.date = date
    log.value = value
    log.habit = habit
    habit.logs.append(log)
}

// MARK: - StatsCalculator Tests

@Suite("StatsCalculator")
struct StatsCalculatorTests {

    // MARK: currentStreak

    @Test("currentStreak returns 0 when no logs exist")
    func currentStreak_noLogs_returnsZero() {
        let habit = makeHabit()
        #expect(StatsCalculator.currentStreak(for: habit) == 0)
    }

    @Test("currentStreak returns 3 when last 3 days completed including today")
    func currentStreak_threeDaysIncludingToday() {
        let habit = makeHabit()
        addLog(to: habit, daysAgo: 0)
        addLog(to: habit, daysAgo: 1)
        addLog(to: habit, daysAgo: 2)
        #expect(StatsCalculator.currentStreak(for: habit) == 3)
    }

    @Test("currentStreak returns 3 when last 3 days before today completed but today not completed")
    func currentStreak_threeDaysBeforeToday_todayNotComplete() {
        let habit = makeHabit()
        addLog(to: habit, daysAgo: 1)
        addLog(to: habit, daysAgo: 2)
        addLog(to: habit, daysAgo: 3)
        #expect(StatsCalculator.currentStreak(for: habit) == 3)
    }

    @Test("currentStreak returns 0 when both yesterday and today are incomplete")
    func currentStreak_yesterdayAndTodayIncomplete_returnsZero() {
        let habit = makeHabit()
        // Only 3+ days ago logs, no yesterday or today
        addLog(to: habit, daysAgo: 5)
        addLog(to: habit, daysAgo: 6)
        #expect(StatsCalculator.currentStreak(for: habit) == 0)
    }

    @Test("currentStreak does not count a gap in the streak")
    func currentStreak_gapBreaksStreak() {
        let habit = makeHabit()
        addLog(to: habit, daysAgo: 0)
        // Gap: daysAgo 1 is missing
        addLog(to: habit, daysAgo: 2)
        addLog(to: habit, daysAgo: 3)
        #expect(StatsCalculator.currentStreak(for: habit) == 1)
    }

    // MARK: bestStreak

    @Test("bestStreak returns 0 for empty logs")
    func bestStreak_noLogs_returnsZero() {
        let habit = makeHabit()
        #expect(StatsCalculator.bestStreak(for: habit) == 0)
    }

    @Test("bestStreak returns longest run even if current streak is shorter")
    func bestStreak_longestRunInPast() {
        let habit = makeHabit()
        // Current streak: just today (1)
        addLog(to: habit, daysAgo: 0)
        // Past streak: 5 consecutive days (20-24 days ago)
        for i in 20...24 {
            addLog(to: habit, daysAgo: i)
        }
        #expect(StatsCalculator.bestStreak(for: habit) == 5)
    }

    @Test("bestStreak returns 1 for a single log")
    func bestStreak_singleLog() {
        let habit = makeHabit()
        addLog(to: habit, daysAgo: 5)
        #expect(StatsCalculator.bestStreak(for: habit) == 1)
    }

    // MARK: completionRate30Days

    @Test("completionRate30Days returns 0.0 when no logs exist")
    func completionRate30Days_noLogs_returnsZero() {
        let habit = makeHabit()
        #expect(StatsCalculator.completionRate30Days(for: habit) == 0.0)
    }

    @Test("completionRate30Days returns 1.0 when all 30 days completed")
    func completionRate30Days_allDaysComplete_returnsOne() {
        let habit = makeHabit()
        for i in 0..<30 {
            addLog(to: habit, daysAgo: i)
        }
        #expect(StatsCalculator.completionRate30Days(for: habit) == 1.0)
    }

    @Test("completionRate30Days returns 0.5 when 15 of 30 days completed")
    func completionRate30Days_halfDaysComplete() {
        let habit = makeHabit()
        for i in 0..<15 {
            addLog(to: habit, daysAgo: i)
        }
        #expect(StatsCalculator.completionRate30Days(for: habit) == 0.5)
    }

    @Test("completionRate30Days ignores days older than 30 days")
    func completionRate30Days_oldLogsIgnored() {
        let habit = makeHabit()
        // Log 35 days ago (outside window)
        addLog(to: habit, daysAgo: 35)
        #expect(StatsCalculator.completionRate30Days(for: habit) == 0.0)
    }

    // MARK: completionByDay

    @Test("completionByDay returns correct count of entries for requested days")
    func completionByDay_returnsCorrectCount() {
        let habit = makeHabit()
        let result = StatsCalculator.completionByDay(for: habit, days: 7)
        #expect(result.count == 7)
    }

    @Test("completionByDay marks completed days correctly")
    func completionByDay_marksCompletedDays() {
        let habit = makeHabit()
        addLog(to: habit, daysAgo: 0)  // today
        addLog(to: habit, daysAgo: 2)  // 2 days ago
        let result = StatsCalculator.completionByDay(for: habit, days: 7)
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntry = result.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        #expect(todayEntry?.completed == true)
    }
}
