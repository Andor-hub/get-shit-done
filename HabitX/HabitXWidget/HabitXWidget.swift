import WidgetKit
import SwiftUI
import SwiftData

// HabitWidgetEntry and MediumWidgetEntry are defined in Models/HabitWidgetEntry.swift

struct HabitTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry(date: .now, habitSnapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitWidgetEntry) -> Void) {
        completion(HabitWidgetEntry(date: .now, habitSnapshot: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitWidgetEntry>) -> Void) {
        let entry = HabitWidgetEntry(date: .now, habitSnapshot: nil)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct HabitXWidgetEntryView: View {
    var entry: HabitWidgetEntry

    var body: some View {
        Text("HabitX")
    }
}

struct HabitXWidget: Widget {
    let kind: String = "HabitXWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitTimelineProvider()) { entry in
            HabitXWidgetEntryView(entry: entry)
                .modelContainer(SharedModelContainer.container)
        }
        .configurationDisplayName("HabitX")
        .description("Track your daily habits.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
