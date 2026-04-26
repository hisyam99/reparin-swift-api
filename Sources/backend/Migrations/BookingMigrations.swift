import Fluent

struct CreateBooking: AsyncMigration {
    func prepare(on database: any Database) async throws {
        _ = try await database.enum("booking_status")
            .case(BookingStatus.requested.rawValue)
            .case(BookingStatus.confirmed.rawValue)
            .case(BookingStatus.inProgress.rawValue)
            .case(BookingStatus.completed.rawValue)
            .case(BookingStatus.cancelled.rawValue)
            .create()

        let bookingStatus = try await database.enum("booking_status").read()

        try await database.schema(Booking.schema)
            .id()
            .field("customer_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("service_id", .uuid, .required, .references(ServiceListing.schema, "id", onDelete: .restrict))
            .field("status", bookingStatus, .required)
            .field("scheduled_at", .datetime, .required)
            .field("customer_note", .string)
            .field("quoted_price", .double, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Booking.schema).delete()
        try await database.enum("booking_status").delete()
    }
}

struct CreateBookingStatusHistory: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let bookingStatus = try await database.enum("booking_status").read()

        try await database.schema(BookingStatusHistory.schema)
            .id()
            .field("booking_id", .uuid, .required, .references(Booking.schema, "id", onDelete: .cascade))
            .field("status", bookingStatus, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(BookingStatusHistory.schema).delete()
    }
}
