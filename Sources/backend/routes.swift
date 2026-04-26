import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get("health") { _ in
        HTTPStatus.ok
    }

    let api = app.grouped("api", "v1")
    try api.register(collection: AuthController())
    try api.register(collection: CategoryController())
    try api.register(collection: ServiceProviderController())
    try api.register(collection: ServiceListingController())
    try api.register(collection: BookingController())
    try api.register(collection: ReviewController())
}
