import Fluent

struct CreateCategory: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Category.schema)
            .id()
            .field("name", .string, .required)
            .field("description", .string)
            .unique(on: "name")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Category.schema).delete()
    }
}

struct CreateServiceProvider: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(ServiceProvider.schema)
            .id()
            .field("business_name", .string, .required)
            .field("bio", .string)
            .field("phone", .string, .required)
            .field("city", .string, .required)
            .field("address", .string, .required)
            .field("is_active", .bool, .required, .sql(.default(true)))
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(ServiceProvider.schema).delete()
    }
}

struct CreateServiceListing: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(ServiceListing.schema)
            .id()
            .field("provider_id", .uuid, .required, .references(ServiceProvider.schema, "id", onDelete: .cascade))
            .field("category_id", .uuid, .required, .references(Category.schema, "id", onDelete: .restrict))
            .field("title", .string, .required)
            .field("description", .string, .required)
            .field("base_price", .double, .required)
            .field("estimated_hours", .int, .required)
            .field("is_active", .bool, .required, .sql(.default(true)))
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(ServiceListing.schema).delete()
    }
}
