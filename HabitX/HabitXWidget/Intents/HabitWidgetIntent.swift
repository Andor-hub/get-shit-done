import AppIntents

/// WidgetConfigurationIntent that lets users pick which habit to display
/// in the small widget's edit-mode configuration UI.
struct HabitWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Habit"
    static let description = IntentDescription("Choose a habit to track.")

    @Parameter(title: "Habit")
    var habit: HabitEntity?
}
