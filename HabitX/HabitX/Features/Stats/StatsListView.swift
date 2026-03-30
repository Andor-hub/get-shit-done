import SwiftUI
import SwiftData

struct StatsListView: View {
    @Query(sort: \HabitSchemaV1.Habit.sortOrder) private var habits: [HabitSchemaV1.Habit]

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No Habits",
                        systemImage: "chart.bar",
                        description: Text("Add habits from the Today tab to see stats here.")
                    )
                } else {
                    List(habits) { habit in
                        NavigationLink(destination: HabitStatsView(habit: habit)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name)
                                    .font(.headline)
                                Text("Current streak: \(StatsCalculator.currentStreak(for: habit)) days")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Stats")
        }
    }
}

#Preview {
    StatsListView()
        .modelContainer(for: [HabitSchemaV1.Habit.self, HabitSchemaV1.HabitLog.self], inMemory: true)
}
