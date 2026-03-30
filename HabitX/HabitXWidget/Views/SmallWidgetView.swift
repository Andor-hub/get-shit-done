import SwiftUI
import WidgetKit
import AppIntents

/// Entry view for the small (single-habit) widget.
/// Renders habit name, circular progress ring with fraction label, and unit/done label.
///
/// Per D-01: habit name top, ring + fraction center, unit label bottom
/// Per D-02: completed state shows filled ring with checkmark and "Done!" label
/// Per D-05: tap dispatches ToggleBooleanHabitIntent (boolean), IncrementCountHabitIntent (count),
///           or opens app via widgetURL deep-link (input)
struct SmallWidgetEntryView: View {
    let entry: HabitWidgetEntry

    var body: some View {
        if let snapshot = entry.habitSnapshot {
            habitContent(snapshot: snapshot)
        } else {
            Text("Select a habit")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    @ViewBuilder
    private func habitContent(snapshot: HabitSnapshot) -> some View {
        let progress = snapshot.dailyTarget > 0 ? snapshot.todayValue / snapshot.dailyTarget : 0
        let content = VStack(spacing: 4) {
            // Habit name at top
            Text(snapshot.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            // Ring with fraction label in center
            ZStack {
                CircularProgressRingView(
                    progress: progress,
                    isCompleted: snapshot.isCompleted,
                    size: 64
                )
                // Show fraction label only when not completed
                if !snapshot.isCompleted {
                    Text(fractionText(snapshot: snapshot))
                        .font(.system(size: 11, weight: .medium))
                }
            }

            // Bottom label: "Done!" when complete, unit otherwise
            if snapshot.isCompleted {
                Text("Done!")
                    .font(.caption2)
                    .foregroundStyle(Color.appAccent)
            } else {
                Text(snapshot.unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        // Wrap with interactivity per D-05
        switch snapshot.habitType {
        case .boolean:
            Button(intent: makeToggleIntent(snapshot: snapshot)) {
                content
            }
            .buttonStyle(.plain)
            .containerBackground(.fill.tertiary, for: .widget)
        case .count:
            Button(intent: makeIncrementIntent(snapshot: snapshot)) {
                content
            }
            .buttonStyle(.plain)
            .containerBackground(.fill.tertiary, for: .widget)
        case .input:
            content
                .widgetURL(URL(string: "habitx://log?id=\(snapshot.id.uuidString)")!)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private func fractionText(snapshot: HabitSnapshot) -> String {
        switch snapshot.habitType {
        case .boolean:
            // Boolean ring only — no fraction text
            return ""
        case .count:
            return "\(Int(snapshot.todayValue))/\(Int(snapshot.dailyTarget))"
        case .input:
            return "\(Int(snapshot.todayValue))/\(Int(snapshot.dailyTarget))\(snapshot.unit)"
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
