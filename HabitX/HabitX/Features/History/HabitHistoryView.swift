import SwiftUI

struct HabitHistoryView: View {
    let habit: HabitSchemaV1.Habit

    /// Dictionary of startOfDay Date -> HabitLog for O(1) lookups
    private var logsByDay: [Date: HabitSchemaV1.HabitLog] {
        var dict: [Date: HabitSchemaV1.HabitLog] = [:]
        for log in habit.logs {
            let day = Calendar.current.startOfDay(for: log.date)
            dict[day] = log
        }
        return dict
    }

    /// Last 90 days in reverse chronological order (most recent first)
    private var last90Days: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<90).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: today)
        }
    }

    var body: some View {
        List(last90Days, id: \.self) { date in
            HStack {
                Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                logValueView(for: date)
            }
            .listRowBackground(rowBackground(for: date))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func logValueView(for date: Date) -> some View {
        let day = Calendar.current.startOfDay(for: date)
        let log = logsByDay[day]

        switch HabitType(rawValue: habit.habitType) {
        case .boolean:
            if let log, log.value >= 1.0 {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.appAccent)
            } else {
                Text("Not completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .count:
            if let log {
                Text("\(Int(log.value))/\(Int(habit.dailyTarget)) \(habit.unit)")
                    .font(.subheadline)
                    .foregroundStyle(log.value >= habit.dailyTarget ? Color.appAccent : .primary)
            } else {
                Text("No entry")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .input:
            if let log {
                Text("\(log.value, specifier: "%.0f")/\(habit.dailyTarget, specifier: "%.0f") \(habit.unit)")
                    .font(.subheadline)
                    .foregroundStyle(log.value >= habit.dailyTarget ? Color.appAccent : .primary)
            } else {
                Text("No entry")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .none:
            if let log {
                Text("\(log.value, specifier: "%.1f")")
                    .font(.subheadline)
            } else {
                Text("No entry")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Subtle accent tint for days where the habit was completed
    private func rowBackground(for date: Date) -> Color? {
        let day = Calendar.current.startOfDay(for: date)
        guard let log = logsByDay[day], log.value >= habit.dailyTarget else {
            return nil
        }
        return Color.appAccent.opacity(0.08)
    }
}

#Preview {
    NavigationStack {
        HabitHistoryView(habit: {
            let h = HabitSchemaV1.Habit()
            h.name = "Water"
            h.habitType = HabitType.count.rawValue
            h.dailyTarget = 8
            h.unit = "cups"
            return h
        }())
    }
}
