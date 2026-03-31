import SwiftUI
import WidgetKit
import AppIntents

/// Entry view for the medium (all-habits) widget.
/// Renders a list of habit rows, each with a mini ring, progress text, and an action button.
///
/// Per D-06: medium widget shows all habits in a scrollable list
/// Per D-07: each row has habit name, mini ring, progress text
/// Per D-08: [+] button dispatches correct intent per habit type
/// Per D-09: completed habits show checkmark instead of fraction; [+] button stays visible
struct MediumWidgetEntryView: View {
    let entry: MediumWidgetEntry

    var body: some View {
        Group {
            if entry.snapshots.isEmpty {
                Text("No habits yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.snapshots, id: \.id) { snapshot in
                        habitRow(snapshot: snapshot)
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func habitRow(snapshot: HabitSnapshot) -> some View {
        let progress = snapshot.dailyTarget > 0 ? snapshot.todayValue / snapshot.dailyTarget : 0
        HStack {
            // Habit name (fills available width)
            Text(snapshot.name)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Mini circular ring (D-07)
            CircularProgressRingView(
                progress: progress,
                isCompleted: snapshot.isCompleted,
                size: 24
            )

            // Progress text or completion checkmark (D-09)
            if snapshot.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.appAccent)
                    .font(.caption)
            } else {
                Text(fractionText(snapshot: snapshot))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Action button per habit type (D-08)
            actionButton(snapshot: snapshot)
        }
    }

    @ViewBuilder
    private func actionButton(snapshot: HabitSnapshot) -> some View {
        switch snapshot.habitType {
        case .boolean:
            Button(intent: makeToggleIntent(snapshot: snapshot)) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.appAccent)
            }
            .buttonStyle(.plain)
        case .count:
            Button(intent: makeIncrementIntent(snapshot: snapshot)) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.appAccent)
            }
            .buttonStyle(.plain)
        case .input:
            Link(destination: URL(string: "habitx://log?id=\(snapshot.id.uuidString)")!) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.appAccent)
            }
        }
    }

    private func fractionText(snapshot: HabitSnapshot) -> String {
        switch snapshot.habitType {
        case .boolean:
            return ""
        case .count:
            return "\(Int(snapshot.todayValue))/\(Int(snapshot.dailyTarget))"
        case .input:
            return "\(Int(snapshot.todayValue))\(snapshot.unit)"
        }
    }

    private func makeToggleIntent(snapshot: HabitSnapshot) -> ToggleBooleanHabitIntent {
        let intent = ToggleBooleanHabitIntent()
        intent.habitId = snapshot.id.uuidString
        return intent
    }

    private func makeIncrementIntent(snapshot: HabitSnapshot) -> IncrementCountHabitIntent {
        let intent = IncrementCountHabitIntent()
        intent.habitId = snapshot.id.uuidString
        return intent
    }
}
