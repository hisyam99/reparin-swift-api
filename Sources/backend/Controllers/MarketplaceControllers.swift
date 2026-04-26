import Fluent
import Vapor

struct RegisterRequest: Content, Validatable {
    let name: String
    let email: String
    let password: String

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

struct LoginRequest: Content, Validatable {
    let email: String
    let password: String

    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: !.empty)
    }
}

struct UserResponse: Content {
    let id: UUID?
    let name: String
    let email: String
}

struct AuthResponse: Content {
    let token: String
    let user: UserResponse
}

struct CategoryResponse: Content {
    let id: UUID?
    let name: String
    let description: String?
}

struct ProviderResponse: Content {
    let id: UUID?
    let businessName: String
    let bio: String?
    let phone: String
    let city: String
    let address: String
}

struct ServiceResponse: Content {
    let id: UUID?
    let title: String
    let description: String
    let basePrice: Double
    let estimatedHours: Int
    let category: CategoryResponse
    let provider: ProviderResponse
}

struct CreateBookingRequest: Content, Validatable {
    let serviceID: UUID
    let scheduledAt: Date
    let customerNote: String?

    static func validations(_ validations: inout Validations) {
        validations.add("serviceID", as: UUID.self)
    }
}

struct BookingResponse: Content {
    let id: UUID?
    let status: BookingStatus
    let scheduledAt: Date
    let customerNote: String?
    let quotedPrice: Double
    let service: ServiceResponse
}

struct CreateReviewRequest: Content, Validatable {
    let bookingID: UUID
    let rating: Int
    let comment: String?

    static func validations(_ validations: inout Validations) {
        validations.add("bookingID", as: UUID.self)
        validations.add("rating", as: Int.self, is: .range(1...5))
    }
}

struct ReviewResponse: Content {
    let id: UUID?
    let bookingID: UUID
    let serviceID: UUID
    let userID: UUID
    let rating: Int
    let comment: String?
    let createdAt: Date?
}

extension User {
    func toResponse() -> UserResponse {
        .init(id: id, name: name, email: email)
    }
}

extension Category {
    func toResponse() -> CategoryResponse {
        .init(id: id, name: name, description: description)
    }
}

extension ServiceProvider {
    func toResponse() -> ProviderResponse {
        .init(
            id: id,
            businessName: businessName,
            bio: bio,
            phone: phone,
            city: city,
            address: address
        )
    }
}

extension ServiceListing {
    func toResponse(category: Category, provider: ServiceProvider) -> ServiceResponse {
        .init(
            id: id,
            title: title,
            description: description,
            basePrice: basePrice,
            estimatedHours: estimatedHours,
            category: category.toResponse(),
            provider: provider.toResponse()
        )
    }
}

struct UserTokenAuthenticator: AsyncBearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        guard let token = try await UserToken.query(on: request.db)
            .filter(\.$value == bearer.token)
            .with(\.$user)
            .first(),
            token.isValid
        else {
            return
        }
        request.auth.login(token.user)
    }
}

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)

        let protected = auth.grouped(UserTokenAuthenticator(), User.guardMiddleware())
        protected.get("me", use: me)
    }

    @Sendable
    func register(req: Request) async throws -> AuthResponse {
        try RegisterRequest.validate(content: req)
        let payload = try req.content.decode(RegisterRequest.self)

        if try await User.query(on: req.db).filter(\.$email == payload.email.lowercased()).first() != nil {
            throw Abort(.conflict, reason: "Email sudah terdaftar.")
        }

        let user = User(
            name: payload.name,
            email: payload.email.lowercased(),
            passwordHash: try Bcrypt.hash(payload.password)
        )
        try await user.save(on: req.db)

        let token = try await createToken(for: user, on: req.db)
        return AuthResponse(token: token.value, user: user.toResponse())
    }

    @Sendable
    func login(req: Request) async throws -> AuthResponse {
        try LoginRequest.validate(content: req)
        let payload = try req.content.decode(LoginRequest.self)

        guard let user = try await User.query(on: req.db)
            .filter(\.$email == payload.email.lowercased())
            .first()
        else {
            throw Abort(.unauthorized, reason: "Email atau password salah.")
        }

        guard try user.verify(password: payload.password) else {
            throw Abort(.unauthorized, reason: "Email atau password salah.")
        }

        let token = try await createToken(for: user, on: req.db)
        return AuthResponse(token: token.value, user: user.toResponse())
    }

    @Sendable
    func me(req: Request) async throws -> UserResponse {
        try req.auth.require(User.self).toResponse()
    }

    private func createToken(for user: User, on db: any Database) async throws -> UserToken {
        let value = [UInt8].random(count: 32).base64
        let expiresAt = Calendar.current.date(byAdding: .day, value: 14, to: Date())
        let token = try UserToken(value: value, userID: user.requireID(), expiresAt: expiresAt)
        try await token.save(on: db)
        return token
    }
}

struct CategoryController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("categories", use: index)
    }

    @Sendable
    func index(req: Request) async throws -> [CategoryResponse] {
        try await Category.query(on: req.db).sort(\.$name).all().map { $0.toResponse() }
    }
}

struct ServiceProviderController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("providers", use: index)
    }

    @Sendable
    func index(req: Request) async throws -> [ProviderResponse] {
        try await ServiceProvider.query(on: req.db)
            .filter(\.$isActive == true)
            .sort(\.$businessName)
            .all()
            .map { $0.toResponse() }
    }
}

struct ServiceListingController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let services = routes.grouped("services")
        services.get(use: index)
        services.get(":serviceID", use: detail)
    }

    @Sendable
    func index(req: Request) async throws -> [ServiceResponse] {
        let query = req.query[String.self, at: "q"]?.lowercased()
        let categoryID = req.query[UUID.self, at: "categoryID"]
        let city = req.query[String.self, at: "city"]?.lowercased()

        let builder = ServiceListing.query(on: req.db)
            .filter(\.$isActive == true)
            .with(\.$category)
            .with(\.$provider)

        if let categoryID {
            builder.filter(\.$category.$id == categoryID)
        }
        if let query, !query.isEmpty {
            builder.group(.or) { group in
                group.filter(\.$title =~ query)
                group.filter(\.$description =~ query)
            }
        }

        let listings = try await builder.all().filter { listing in
            guard let city else { return true }
            return listing.provider.city.lowercased().contains(city)
        }

        return listings.map { $0.toResponse(category: $0.category, provider: $0.provider) }
    }

    @Sendable
    func detail(req: Request) async throws -> ServiceResponse {
        guard let serviceID = req.parameters.get("serviceID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "serviceID tidak valid.")
        }
        guard let service = try await ServiceListing.query(on: req.db)
            .filter(\.$id == serviceID)
            .with(\.$category)
            .with(\.$provider)
            .first()
        else {
            throw Abort(.notFound, reason: "Service tidak ditemukan.")
        }

        return service.toResponse(category: service.category, provider: service.provider)
    }
}

struct BookingController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(UserTokenAuthenticator(), User.guardMiddleware())
        let bookings = protected.grouped("bookings")
        bookings.get(use: index)
        bookings.get(":bookingID", use: detail)
        bookings.post(use: create)
        bookings.post(":bookingID", "cancel", use: cancel)
    }

    @Sendable
    func index(req: Request) async throws -> [BookingResponse] {
        let user = try req.auth.require(User.self)
        let bookings = try await Booking.query(on: req.db)
            .filter(\.$customer.$id == user.requireID())
            .sort(\.$createdAt, .descending)
            .all()

        var responses: [BookingResponse] = []
        for booking in bookings {
            let service = try await loadServiceResponse(serviceID: booking.$service.id, on: req.db)
            responses.append(
                BookingResponse(
                    id: booking.id,
                    status: booking.status,
                    scheduledAt: booking.scheduledAt,
                    customerNote: booking.customerNote,
                    quotedPrice: booking.quotedPrice,
                    service: service
                )
            )
        }
        return responses
    }

    @Sendable
    func detail(req: Request) async throws -> BookingResponse {
        let user = try req.auth.require(User.self)
        guard let bookingID = req.parameters.get("bookingID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "bookingID tidak valid.")
        }
        guard let booking = try await Booking.query(on: req.db)
            .filter(\.$id == bookingID)
            .filter(\.$customer.$id == user.requireID())
            .first()
        else {
            throw Abort(.notFound, reason: "Booking tidak ditemukan.")
        }
        let service = try await loadServiceResponse(serviceID: booking.$service.id, on: req.db)

        return BookingResponse(
            id: booking.id,
            status: booking.status,
            scheduledAt: booking.scheduledAt,
            customerNote: booking.customerNote,
            quotedPrice: booking.quotedPrice,
            service: service
        )
    }

    @Sendable
    func create(req: Request) async throws -> BookingResponse {
        let user = try req.auth.require(User.self)
        try CreateBookingRequest.validate(content: req)
        let payload = try req.content.decode(CreateBookingRequest.self)

        guard let service = try await ServiceListing.query(on: req.db)
            .filter(\.$id == payload.serviceID)
            .filter(\.$isActive == true)
            .with(\.$category)
            .with(\.$provider)
            .first()
        else {
            throw Abort(.notFound, reason: "Service tidak ditemukan.")
        }

        let booking = try Booking(
            customerID: user.requireID(),
            serviceID: service.requireID(),
            status: .requested,
            scheduledAt: payload.scheduledAt,
            customerNote: payload.customerNote,
            quotedPrice: service.basePrice
        )
        try await booking.save(on: req.db)

        let history = try BookingStatusHistory(bookingID: booking.requireID(), status: .requested)
        try await history.save(on: req.db)

        return BookingResponse(
            id: booking.id,
            status: booking.status,
            scheduledAt: booking.scheduledAt,
            customerNote: booking.customerNote,
            quotedPrice: booking.quotedPrice,
            service: service.toResponse(category: service.category, provider: service.provider)
        )
    }

    @Sendable
    func cancel(req: Request) async throws -> BookingResponse {
        let user = try req.auth.require(User.self)
        guard let bookingID = req.parameters.get("bookingID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "bookingID tidak valid.")
        }
        guard let booking = try await Booking.query(on: req.db)
            .filter(\.$id == bookingID)
            .filter(\.$customer.$id == user.requireID())
            .first()
        else {
            throw Abort(.notFound, reason: "Booking tidak ditemukan.")
        }

        guard booking.status == .requested || booking.status == .confirmed else {
            throw Abort(.badRequest, reason: "Booking tidak bisa dibatalkan di status saat ini.")
        }

        booking.status = .cancelled
        try await booking.save(on: req.db)

        let history = try BookingStatusHistory(bookingID: booking.requireID(), status: .cancelled)
        try await history.save(on: req.db)
        let service = try await loadServiceResponse(serviceID: booking.$service.id, on: req.db)

        return BookingResponse(
            id: booking.id,
            status: booking.status,
            scheduledAt: booking.scheduledAt,
            customerNote: booking.customerNote,
            quotedPrice: booking.quotedPrice,
            service: service
        )
    }

    private func loadServiceResponse(serviceID: UUID, on db: any Database) async throws -> ServiceResponse {
        guard let service = try await ServiceListing.query(on: db)
            .filter(\.$id == serviceID)
            .with(\.$category)
            .with(\.$provider)
            .first()
        else {
            throw Abort(.notFound, reason: "Service tidak ditemukan.")
        }
        return service.toResponse(category: service.category, provider: service.provider)
    }
}

struct ReviewController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("reviews", use: list)

        let protected = routes.grouped(UserTokenAuthenticator(), User.guardMiddleware())
        protected.post("reviews", use: create)
    }

    @Sendable
    func list(req: Request) async throws -> [ReviewResponse] {
        let serviceID = req.query[UUID.self, at: "serviceID"]
        let providerID = req.query[UUID.self, at: "providerID"]

        let builder = Review.query(on: req.db)

        if let serviceID {
            builder.filter(\.$service.$id == serviceID)
        }
        if let providerID {
            let serviceIDs = try await ServiceListing.query(on: req.db)
                .filter(\.$provider.$id == providerID)
                .all(\.$id)
                .compactMap { $0 }
            builder.filter(\.$service.$id ~~ serviceIDs)
        }

        let reviews = try await builder.sort(\.$createdAt, .descending).all()
        return reviews.map {
            ReviewResponse(
                id: $0.id,
                bookingID: $0.$booking.id,
                serviceID: $0.$service.id,
                userID: $0.$user.id,
                rating: $0.rating,
                comment: $0.comment,
                createdAt: $0.createdAt
            )
        }
    }

    @Sendable
    func create(req: Request) async throws -> ReviewResponse {
        let user = try req.auth.require(User.self)
        try CreateReviewRequest.validate(content: req)
        let payload = try req.content.decode(CreateReviewRequest.self)

        guard let booking = try await Booking.query(on: req.db)
            .filter(\.$id == payload.bookingID)
            .filter(\.$customer.$id == user.requireID())
            .first()
        else {
            throw Abort(.notFound, reason: "Booking tidak ditemukan.")
        }

        guard booking.status == .completed else {
            throw Abort(.badRequest, reason: "Review hanya bisa dibuat saat booking selesai.")
        }

        if try await Review.query(on: req.db).filter(\.$booking.$id == booking.requireID()).first() != nil {
            throw Abort(.conflict, reason: "Review untuk booking ini sudah ada.")
        }

        let review = try Review(
            bookingID: booking.requireID(),
            serviceID: booking.$service.id,
            userID: user.requireID(),
            rating: payload.rating,
            comment: payload.comment
        )
        try await review.save(on: req.db)

        return ReviewResponse(
            id: review.id,
            bookingID: review.$booking.id,
            serviceID: review.$service.id,
            userID: review.$user.id,
            rating: review.rating,
            comment: review.comment,
            createdAt: review.createdAt
        )
    }
}
