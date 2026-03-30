import SwiftUI
import Charts

struct HabitStatsView: View {
    let habit: HabitSchemaV1.Habit

    private var currentStreak: Int { StatsCalculator.currentStreak(for: habit) }
    private var bestStreak: Int { StatsCalculator.bestStreak(for: habit) }
    private var completionRate: Double { StatsCalculator.completionRate30Days(for: habit) }
    private var completionData: [(date: Date, completed: Bool)] {
        StatsCalculator.completionByDay(for: habit, days: 30)
    }

    private var completedCount: Int {
        completionData.filter(\.completed).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Stat Cards
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 12
                ) {
                    StatCard(
                        title: "Current Streak",
                        value: "\(currentStreak)",
                        subtitle: "days"
                    )
                    StatCard(
                        title: "Best Streak",
                        value: "\(bestStreak)",
                        subtitle: "days"
                    )
                    StatCard(
                        title: "30-Day Rate",
                        value: "\(Int(completionRate * 100))%",
                        subtitle: nil
                    )
                }
                .padding(.horizontal)

                // MARK: - 30-Day Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 30 Days")
                        .font(.headline)
                        .padding(.horizontal)

                    Chart(completionData, id: \.date) { entry in
                        BarMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Completed", entry.completed ? 1 : 0)
                        )
                        .foregroundStyle(entry.completed ? Color.appAccent : Color(.systemGray4))
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { value in
                            AxisValueLabel(format: .dateTime.day())
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)

                    Text("\(completedCount) of 30 days completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Stat Card Component

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.appAccent)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    NavigationStack {
        HabitStatsView(habit: {
            let h = HabitSchemaV1.Habit()
            h.name = "Water"
            h.habitType = HabitType.count.rawValue
            h.dailyTarget = 8
            h.unit = "cups"
            return h
        }())
    }
}
