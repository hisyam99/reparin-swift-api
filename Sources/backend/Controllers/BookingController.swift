import Fluent
import Vapor

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
