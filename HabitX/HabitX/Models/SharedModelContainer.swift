import SwiftData

enum SharedModelContainer {
    static let container: ModelContainer = {
        let schema = Schema(versionedSchema: HabitSchemaV1.self)
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.com.habitx.shared")
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: HabitMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("SharedModelContainer: failed to initialize — \(error)")
        }
    }()
}
