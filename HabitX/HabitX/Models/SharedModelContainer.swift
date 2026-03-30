import SwiftData
import Foundation

enum SharedModelContainer {
    static let container: ModelContainer = {
        let schema = Schema(versionedSchema: HabitSchemaV1.self)

        // Use App Group container when available (app + widget share the same SQLite store).
        // Fall back to the default documents directory when App Group is not provisioned —
        // this happens in unit test runners and un-provisioned simulators.
        let config: ModelConfiguration
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.habitx.shared"
        ) {
            let storeURL = groupURL.appendingPathComponent("HabitX.sqlite")
            config = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            // Fallback: store in app's Documents directory (no widget sharing, but functional)
            config = ModelConfiguration(schema: schema)
        }

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
