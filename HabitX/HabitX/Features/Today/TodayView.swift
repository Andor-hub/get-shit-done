import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \HabitSchemaV1.Habit.sortOrder) private var habits: [HabitSchemaV1.Habit]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddSheet = false
    @State private var habitToEdit: HabitSchemaV1.Habit? = nil
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
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                HabitTemplatePickerView(habitCount: habits.count)
            }
            .sheet(item: $habitToEdit) { habit in
                HabitFormView(habit: habit, isNew: false)
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
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
        }
    }

    private var habitList: some View {
        List {
            ForEach(habits) { habit in
                HabitCardView(habit: habit, onEdit: {
                    habitToEdit = habit
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
