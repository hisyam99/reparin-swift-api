import Fluent
import FluentPostgresDriver
import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    app.databases.use(
        .postgres(
            configuration: .init(
                hostname: Environment.get("DATABASE_HOST") ?? "localhost",
                port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? 5432,
                username: Environment.get("DATABASE_USERNAME") ?? "postgres",
                password: Environment.get("DATABASE_PASSWORD") ?? "postgres",
                database: Environment.get("DATABASE_NAME") ?? "hisyam-swift1",
                tls: .disable
            )
        ),
        as: .psql
    )

    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateCategory())
    app.migrations.add(CreateServiceProvider())
    app.migrations.add(CreateServiceListing())
    app.migrations.add(CreateBooking())
    app.migrations.add(CreateBookingStatusHistory())
    app.migrations.add(CreateReview())
    app.migrations.add(SeedMarketplaceData())

    app.views.use(.leaf)

    // register routes
    try routes(app)
}
