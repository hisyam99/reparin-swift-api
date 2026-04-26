import Fluent

struct CreateReview: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Review.schema)
            .id()
            .field("booking_id", .uuid, .required, .references(Booking.schema, "id", onDelete: .cascade))
            .field("service_id", .uuid, .required, .references(ServiceListing.schema, "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("rating", .int, .required)
            .field("comment", .string)
            .field("created_at", .datetime)
            .unique(on: "booking_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Review.schema).delete()
    }
}
