import Fluent
import Vapor

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
