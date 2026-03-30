import SwiftUI
import SwiftData

struct NumberInputSheet: View {
    let habit: HabitSchemaV1.Habit

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var inputValue: String = ""

    private var parsedValue: Double? {
        Double(inputValue)
    }

    private var isLogEnabled: Bool {
        parsedValue != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Value", text: $inputValue)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Enter \(habit.unit.isEmpty ? "value" : habit.unit)")
                }

                if let current = parsedValue {
                    Section {
                        let target = habit.dailyTarget
                        let label = target > 0 ? "\(String(format: "%.0f", current))/\(String(format: "%.0f", target)) \(habit.unit)" : "\(String(format: "%.0f", current)) \(habit.unit)"
                        Text(label)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Preview")
                    }
                }
            }
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        if let value = parsedValue {
                            HabitLogService.setValue(habit: habit, value: value, context: modelContext)
                            dismiss()
                        }
                    }
                    .disabled(!isLogEnabled)
                }
            }
        }
    }
}
