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
    @State private var reminderEnabled: Bool = false
    @State private var reminderTime: Date = Calendar.current.date(
        bySettingHour: 8, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var notificationsDenied: Bool = false

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

                Section("Reminders") {
                    Toggle("Remind me", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                    if notificationsDenied {
                        Text("Enable notifications in Settings to receive reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                reminderEnabled = habit.reminderTime != nil
                if let existingTime = habit.reminderTime {
                    reminderTime = existingTime
                }
            }
            .onChange(of: reminderEnabled) { _, isEnabled in
                if isEnabled {
                    Task {
                        let granted = await NotificationService.requestAuthorizationIfNeeded()
                        if !granted {
                            notificationsDenied = true
                            reminderEnabled = false
                        } else {
                            notificationsDenied = false
                        }
                    }
                }
            }
        }
    }

    private func save() {
        // Write state back to the habit model
        habit.name = name.trimmingCharacters(in: .whitespaces)
        habit.habitType = selectedType.rawValue
        habit.dailyTarget = Double(targetString) ?? 1.0
        habit.unit = unit

        if reminderEnabled {
            habit.reminderTime = reminderTime
            Task { await NotificationService.scheduleReminder(for: habit) }
        } else {
            habit.reminderTime = nil
            NotificationService.cancelReminder(for: habit)
        }

        if isNew {
            modelContext.insert(habit)
        }
        // For edit mode, SwiftData auto-persists; just dismiss
        dismiss()
    }
}
