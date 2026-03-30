import Testing
import Foundation
import SwiftData
@testable import HabitX

// MARK: - HabitLogService Tests

@Suite("HabitLogService")
struct HabitLogServiceTests {

    // MARK: - Test Container Setup

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: HabitSchemaV1.Habit.self, HabitSchemaV1.HabitLog.self,
            configurations: config
        )
    }

    private func makeHabit(type: HabitType = .boolean, dailyTarget: Double = 1.0) -> HabitSchemaV1.Habit {
        let habit = HabitSchemaV1.Habit()
        habit.habitType = type.rawValue
        habit.dailyTarget = dailyTarget
        return habit
    }

    // MARK: - toggleBoolean

    @Test("toggleBoolean creates log when none exists for today")
    @MainActor
    func toggleBoolean_noExistingLog_createsLog() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit(type: .boolean)
        context.insert(habit)

        HabitLogService.toggleBoolean(habit: habit, context: context)

        #expect(habit.logs.count == 1)
        #expect(habit.logs.first?.value == 1.0)
    }

    @Test("toggleBoolean deletes log when one exists for today")
    @MainActor
    func toggleBoolean_existingLog_deletesLog() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit(type: .boolean)
        context.insert(habit)

        // First toggle — creates log
        HabitLogService.toggleBoolean(habit: habit, context: context)
        try context.save()
        #expect(habit.logs.count == 1)

        // Second toggle — deletes log
        HabitLogService.toggleBoolean(habit: habit, context: context)
        try context.save()
        #expect(habit.logs.count == 0)
    }

    // MARK: - incrementCount

    @Test("incrementCount creates log with value 1 when none exists")
    @MainActor
    func incrementCount_noExistingLog_createsLogWithValueOne() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit(type: .count)
        context.insert(habit)

        HabitLogService.incrementCount(habit: habit, context: context)

        #expect(habit.logs.count == 1)
        #expect(habit.logs.first?.value == 1.0)
    }

    @Test("incrementCount adds 1 to existing log value")
    @MainActor
    func incrementCount_existingLog_incrementsValue() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit(type: .count)
        context.insert(habit)

        HabitLogService.incrementCount(habit: habit, context: context)
        HabitLogService.incrementCount(habit: habit, context: context)

        #expect(habit.logs.count == 1)
        #expect(habit.logs.first?.value == 2.0)
    }

    @Test("incrementCount adds 1 on third call resulting in value 3")
    @MainActor
    func incrementCount_threeCallsResultsInValueThree() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit(type: .count)
        context.insert(habit)

        HabitLogService.incrementCount(habit: habit, context: context)
        HabitLogService.incrementCount(habit: habit, context: context)
        HabitLogService.incrementCount(habit: habit, context: context)

        #expect(habit.logs.first?.value == 3.0)
    }

    // MARK: - setValue

    @Test("setValue creates log with specified value when none exists")
    @MainActor
    func setValue_noExistingLog_createsLogWithValue() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit(type: .input)
        context.insert(habit)

        HabitLogService.setValue(habit: habit, value: 120.0, context: context)

        #expect(habit.logs.count == 1)
        #expect(habit.logs.first?.value == 120.0)
    }

    @Test("setValue updates existing log value")
    @MainActor
    func setValue_existingLog_updatesValue() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit(type: .input)
        context.insert(habit)

        HabitLogService.setValue(habit: habit, value: 80.0, context: context)
        HabitLogService.setValue(habit: habit, value: 150.0, context: context)

        #expect(habit.logs.count == 1)
        #expect(habit.logs.first?.value == 150.0)
    }

    // MARK: - todayValue

    @Test("todayValue returns 0 when no log exists")
    func todayValue_noLog_returnsZero() {
        let habit = makeHabit()
        #expect(HabitLogService.todayValue(for: habit) == 0.0)
    }

    @Test("todayValue returns correct value for today's log")
    @MainActor
    func todayValue_withLog_returnsValue() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit(type: .input, dailyTarget: 150.0)
        context.insert(habit)

        HabitLogService.setValue(habit: habit, value: 95.0, context: context)

        #expect(HabitLogService.todayValue(for: habit) == 95.0)
    }

    @Test("todayValue ignores logs from previous days")
    func todayValue_oldLog_returnsZero() {
        let habit = makeHabit()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let log = HabitSchemaV1.HabitLog()
        log.date = yesterday
        log.value = 1.0
        log.habit = habit
        habit.logs.append(log)

        #expect(HabitLogService.todayValue(for: habit) == 0.0)
    }

    // MARK: - isCompleted

    @Test("isCompleted returns false when no log exists")
    func isCompleted_noLog_returnsFalse() {
        let habit = makeHabit()
        #expect(HabitLogService.isCompleted(habit: habit) == false)
    }

    @Test("isCompleted returns true when value meets daily target")
    @MainActor
    func isCompleted_valueMetTarget_returnsTrue() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit(type: .boolean, dailyTarget: 1.0)
        context.insert(habit)

        HabitLogService.toggleBoolean(habit: habit, context: context)

        #expect(HabitLogService.isCompleted(habit: habit) == true)
    }

    @Test("isCompleted returns false when value below daily target")
    @MainActor
    func isCompleted_valueBelowTarget_returnsFalse() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let habit = makeHabit(type: .count, dailyTarget: 8.0)
        context.insert(habit)

        HabitLogService.incrementCount(habit: habit, context: context)

        #expect(HabitLogService.isCompleted(habit: habit) == false)
    }
}
