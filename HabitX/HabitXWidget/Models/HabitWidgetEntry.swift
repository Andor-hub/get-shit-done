import WidgetKit
import Foundation

/// TimelineEntry for the small (single-habit) widget.
/// Contains an optional HabitSnapshot; nil when no habit has been configured yet.
struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    let habitSnapshot: HabitSnapshot?
}

/// TimelineEntry for the medium (multi-habit) widget.
/// Contains an array of HabitSnapshots for all habits to display.
struct MediumWidgetEntry: TimelineEntry {
    let date: Date
    let snapshots: [HabitSnapshot]
}
