import SwiftUI
import SwiftData

struct HabitCardView: View {
    let habit: HabitSchemaV1.Habit
    /// Called when the user taps the edit-mode gesture (or to open edit sheet).
    var onEdit: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    @State private var showingNumberInput = false

    private var todayValue: Double {
        HabitLogService.todayValue(for: habit)
    }

    private var isCompleted: Bool {
        HabitLogService.isCompleted(habit: habit)
    }

    private var habitType: HabitType {
        HabitType(rawValue: habit.habitType) ?? .boolean
    }

    private var progressText: String {
        switch habitType {
        case .boolean:
            return isCompleted ? "Done" : "Not done"
        case .count:
            return "\(Int(todayValue))/\(Int(habit.dailyTarget)) \(habit.unit)"
        case .input:
            let current = String(format: "%.0f", todayValue)
            let target = String(format: "%.0f", habit.dailyTarget)
            return "\(current)/\(target) \(habit.unit)"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundStyle(isCompleted ? Color.appAccent : .primary)
                Text(progressText)
                    .font(.subheadline)
                    .foregroundStyle(isCompleted ? Color.appAccent.opacity(0.8) : .secondary)
            }
            Spacer()
            if editMode?.wrappedValue.isEditing == false {
                actionButton
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompleted ? Color.appAccent.opacity(0.12) : Color(.secondarySystemBackground))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if editMode?.wrappedValue.isEditing == true {
                onEdit?()
            } else if habitType == .boolean {
                HabitLogService.toggleBoolean(habit: habit, context: modelContext)
            }
        }
        .sheet(isPresented: $showingNumberInput) {
            NumberInputSheet(habit: habit)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch habitType {
        case .boolean:
            EmptyView()
        case .count:
            Button {
                HabitLogService.incrementCount(habit: habit, context: modelContext)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.appAccent)
            }
            .buttonStyle(.plain)
        case .input:
            Button {
                showingNumberInput = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.appAccent)
            }
            .buttonStyle(.plain)
        }
    }
}
