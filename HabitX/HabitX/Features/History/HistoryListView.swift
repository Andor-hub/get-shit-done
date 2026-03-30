import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Query(sort: \HabitSchemaV1.Habit.sortOrder) private var habits: [HabitSchemaV1.Habit]

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No Habits",
                        systemImage: "clock",
                        description: Text("Add habits from the Today tab to see history here.")
                    )
                } else {
                    List(habits) { habit in
                        NavigationLink(destination: HabitHistoryView(habit: habit)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name)
                                    .font(.headline)
                                Text(habitSubtitle(for: habit))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
        }
    }

    private func habitSubtitle(for habit: HabitSchemaV1.Habit) -> String {
        switch HabitType(rawValue: habit.habitType) {
        case .boolean:
            return "Daily completion"
        case .count:
            let target = Int(habit.dailyTarget)
            let unit = habit.unit.isEmpty ? "times" : habit.unit
            return "Goal: \(target) \(unit)/day"
        case .input:
            let target = Int(habit.dailyTarget)
            let unit = habit.unit.isEmpty ? "units" : habit.unit
            return "Goal: \(target) \(unit)/day"
        case .none:
            return habit.unit
        }
    }
}

#Preview {
    HistoryListView()
        .modelContainer(for: [HabitSchemaV1.Habit.self, HabitSchemaV1.HabitLog.self], inMemory: true)
}
