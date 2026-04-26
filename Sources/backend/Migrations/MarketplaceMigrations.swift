import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(User.schema)
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "email")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(User.schema).delete()
    }
}

struct CreateUserToken: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(UserToken.schema)
            .id()
            .field("value", .string, .required)
            .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("expires_at", .datetime)
            .unique(on: "value")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(UserToken.schema).delete()
    }
}

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

struct SeedMarketplaceData: AsyncMigration {
    func prepare(on database: any Database) async throws {
        if try await Category.query(on: database).first() != nil {
            return
        }

        let categories = [
            Category(name: "Phone Repair", description: "Perbaikan smartphone dan tablet."),
            Category(name: "Laptop Service", description: "Upgrade, cleaning, dan troubleshooting laptop."),
            Category(name: "Console Repair", description: "Servis perangkat gaming console.")
        ]
        try await categories.create(on: database)

        let providers = [
            ServiceProvider(
                businessName: "FixNow Gadget Center",
                bio: "Spesialis kerusakan motherboard dan water damage.",
                phone: "081234567890",
                city: "Jakarta",
                address: "Jl. Sudirman No. 100"
            ),
            ServiceProvider(
                businessName: "LaptopCare Studio",
                bio: "Fokus pada performa dan thermal tuning laptop.",
                phone: "081298765432",
                city: "Bandung",
                address: "Jl. Asia Afrika No. 45"
            )
        ]
        try await providers.create(on: database)

        guard
            let phoneCategoryID = categories.first?.id,
            let laptopCategoryID = categories.dropFirst().first?.id,
            let firstProviderID = providers.first?.id,
            let secondProviderID = providers.dropFirst().first?.id
        else {
            return
        }

        let services = [
            ServiceListing(
                providerID: firstProviderID,
                categoryID: phoneCategoryID,
                title: "Ganti LCD iPhone/Android",
                description: "Penggantian layar retak dengan garansi 30 hari.",
                basePrice: 350_000,
                estimatedHours: 3
            ),
            ServiceListing(
                providerID: secondProviderID,
                categoryID: laptopCategoryID,
                title: "Cleaning + Thermal Paste Laptop",
                description: "Pembersihan menyeluruh dan penggantian thermal paste.",
                basePrice: 250_000,
                estimatedHours: 2
            )
        ]
        try await services.create(on: database)
    }

    func revert(on database: any Database) async throws {
        try await Review.query(on: database).delete()
        try await BookingStatusHistory.query(on: database).delete()
        try await Booking.query(on: database).delete()
        try await ServiceListing.query(on: database).delete()
        try await ServiceProvider.query(on: database).delete()
        try await Category.query(on: database).delete()
    }
}
