import SwiftUI
import SwiftData

/// Sheet that lets the user pick a habit template (Protein, Water, or Custom).
/// After picking, presents HabitFormView pre-filled with template values.
struct HabitTemplatePickerView: View {
    let habitCount: Int

    @Environment(\.dismiss) private var dismiss

    // Non-nil value triggers the form sheet; item: passes it directly — no if-let race
    @State private var pendingHabit: HabitSchemaV1.Habit? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    templateRow(
                        title: "Protein",
                        subtitle: "150g daily target, input type",
                        systemImage: "fork.knife",
                        template: .proteinTemplate
                    )
                    templateRow(
                        title: "Water",
                        subtitle: "8 cups daily target, count type",
                        systemImage: "drop",
                        template: .waterTemplate
                    )
                } header: {
                    Text("Templates")
                }

                Section {
                    Button {
                        let blank = HabitSchemaV1.Habit()
                        blank.sortOrder = habitCount
                        pendingHabit = blank
                    } label: {
                        HStack {
                            Label("Custom Habit", systemImage: "plus.circle")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("Start from scratch")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $pendingHabit) { habit in
                HabitFormView(habit: habit, isNew: true)
                    .onDisappear {
                        // Habit was saved if it has a name and a context
                        if !habit.name.isEmpty && habit.modelContext != nil {
                            dismiss()
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func templateRow(
        title: String,
        subtitle: String,
        systemImage: String,
        template: HabitTemplate
    ) -> some View {
        Button {
            pendingHabit = createHabit(from: template, sortOrder: habitCount)
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.primary)
                Spacer()
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
