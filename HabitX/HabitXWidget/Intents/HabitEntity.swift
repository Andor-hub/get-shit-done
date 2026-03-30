import AppIntents
import Foundation

/// Value-type wrapper around a Habit, conforming to AppEntity.
/// Used as the configuration parameter in HabitWidgetIntent's picker dropdown.
struct HabitEntity: AppEntity {
    var id: UUID
    var name: String
    var habitType: String
    var unit: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Habit")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static let defaultQuery = HabitEntityQuery()
}
