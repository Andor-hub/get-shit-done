import SwiftUI
import SwiftData

private enum TodaySheet: Identifiable {
    case addHabit
    case editHabit(HabitSchemaV1.Habit)

    var id: String {
        switch self {
        case .addHabit: return "addHabit"
        case .editHabit(let habit): return "editHabit-\(habit.id)"
        }
    }
}

struct TodayView: View {
    @Query(sort: \HabitSchemaV1.Habit.sortOrder) private var habits: [HabitSchemaV1.Habit]
    @Environment(\.modelContext) private var modelContext

    @State private var activeSheet: TodaySheet? = nil
    @State private var habitToDelete: HabitSchemaV1.Habit? = nil
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    emptyStateView
                } else {
                    habitList
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .addHabit
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addHabit:
                    HabitTemplatePickerView(habitCount: habits.count)
                case .editHabit(let habit):
                    HabitFormView(habit: habit, isNew: false)
                }
            }
            .confirmationDialog(
                deleteDialogTitle,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let habit = habitToDelete {
                        modelContext.delete(habit)
                        habitToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    habitToDelete = nil
                }
            }
        }
    }

    private var deleteDialogTitle: String {
        if let name = habitToDelete?.name {
            return "Delete \(name)?"
        }
        return "Delete habit?"
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.appAccent)
            Text("No habits yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Add Habit") {
                activeSheet = .addHabit
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
        }
    }

    private var habitList: some View {
        List {
            ForEach(habits) { habit in
                HabitCardView(habit: habit, onEdit: {
                    activeSheet = .editHabit(habit)
                })
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onMove(perform: moveHabits)
            .onDelete(perform: requestDelete)
        }
        .listStyle(.plain)
    }

    private func moveHabits(from source: IndexSet, to destination: Int) {
        var reordered = habits
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in reordered.enumerated() {
            habit.sortOrder = index
        }
    }

    private func requestDelete(at offsets: IndexSet) {
        if let index = offsets.first {
            habitToDelete = habits[index]
            showDeleteConfirmation = true
        }
    }
}

#Preview {
    TodayView()
}
