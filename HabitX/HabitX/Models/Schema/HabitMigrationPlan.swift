import SwiftData

enum HabitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [HabitSchemaV1.self]
    }
    static var stages: [MigrationStage] { [] }
}
