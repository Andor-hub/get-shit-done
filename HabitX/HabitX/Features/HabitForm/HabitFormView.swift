import SwiftUI
import SwiftData

/// Reusable form for creating or editing a habit.
/// - isNew == true: caller is responsible for inserting `habit` into ModelContext on save
/// - isNew == false: edits the live model; changes are captured on save via copied state
struct HabitFormView: View {
    let habit: HabitSchemaV1.Habit
    let isNew: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Local copies of fields so we can cancel cleanly in both add and edit mode
    @State private var name: String = ""
    @State private var selectedType: HabitType = .boolean
    @State private var targetString: String = ""
    @State private var unit: String = ""

    private var isSaveEnabled: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $selectedType) {
                        ForEach(HabitType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                }

                Section("Target") {
                    TextField("Daily Target", text: $targetString)
                        .keyboardType(.decimalPad)
                    TextField("Unit (e.g. cups, g)", text: $unit)
                }
            }
            .navigationTitle(isNew ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isSaveEnabled)
                }
            }
            .onAppear {
                // Populate state from the habit model
                name = habit.name
                selectedType = HabitType(rawValue: habit.habitType) ?? .boolean
                let target = habit.dailyTarget
                targetString = target == 0 ? "" : String(format: "%.0f", target)
                unit = habit.unit
            }
        }
    }

    private func save() {
        // Write state back to the habit model
        habit.name = name.trimmingCharacters(in: .whitespaces)
        habit.habitType = selectedType.rawValue
        habit.dailyTarget = Double(targetString) ?? 1.0
        habit.unit = unit

        if isNew {
            modelContext.insert(habit)
        }
        // For edit mode, SwiftData auto-persists; just dismiss
        dismiss()
    }
}
