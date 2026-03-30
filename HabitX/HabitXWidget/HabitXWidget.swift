import WidgetKit
import SwiftUI

/// Small widget — one habit per widget, configurable via HabitWidgetIntent picker.
/// Uses AppIntentConfiguration so users can pick which habit to display.
///
/// Per plan: kind string is stable ("HabitSmallWidget") — never change after ship.
/// @main is NOT here; it lives on HabitXWidgetBundle only.
struct HabitSmallWidget: Widget {
    let kind: String = "HabitSmallWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HabitWidgetIntent.self,
            provider: SmallWidgetProvider()
        ) { entry in
            SmallWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habit")
        .description("Track a single habit from your home screen.")
        .supportedFamilies([.systemSmall])
    }
}

/// Medium widget — shows all habits at a glance, no per-widget configuration.
/// Uses StaticConfiguration because it always displays every habit.
///
/// Per plan: kind string is stable ("HabitMediumWidget") — never change after ship.
struct HabitMediumWidget: Widget {
    let kind: String = "HabitMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MediumWidgetProvider()) { entry in
            MediumWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("All Habits")
        .description("See all your habits at a glance.")
        .supportedFamilies([.systemMedium])
    }
}
