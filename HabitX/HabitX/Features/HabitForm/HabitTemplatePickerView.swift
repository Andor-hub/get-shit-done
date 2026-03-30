import SwiftUI
import SwiftData

/// Sheet that lets the user pick a habit template (Protein, Water, or Custom).
/// After picking, it navigates into HabitFormView for final field editing.
struct HabitTemplatePickerView: View {
    /// Number of existing habits — used to set sortOrder for the new habit.
    let habitCount: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var pendingHabit: HabitSchemaV1.Habit? = nil
    @State private var showingForm = false

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
                        showingForm = true
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
            .sheet(isPresented: $showingForm) {
                if let habit = pendingHabit {
                    HabitFormView(habit: habit, isNew: true)
                        .onDisappear {
                            if !habit.name.isEmpty && habit.modelContext != nil {
                                dismiss()
                            }
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
            // Create the habit on tap, not during view body evaluation
            let habit = createHabit(from: template, sortOrder: habitCount)
            pendingHabit = habit
            showingForm = true
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
