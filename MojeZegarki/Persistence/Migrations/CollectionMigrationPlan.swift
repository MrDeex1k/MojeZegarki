import SwiftData

enum CollectionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CollectionSchemaV1.self, CollectionSchemaV2.self, CollectionSchemaV3.self]
    }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: CollectionSchemaV1.self, toVersion: CollectionSchemaV2.self),
            .lightweight(fromVersion: CollectionSchemaV2.self, toVersion: CollectionSchemaV3.self),
        ]
    }
}
