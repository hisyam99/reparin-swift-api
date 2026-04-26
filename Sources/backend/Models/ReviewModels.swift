import Fluent
import Vapor

final class Review: Model, Content, @unchecked Sendable {
    static let schema = "reviews"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "booking_id")
    var booking: Booking

    @Parent(key: "service_id")
    var service: ServiceListing

    @Parent(key: "user_id")
    var user: User

    @Field(key: "rating")
    var rating: Int

    @OptionalField(key: "comment")
    var comment: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        bookingID: UUID,
        serviceID: UUID,
        userID: UUID,
        rating: Int,
        comment: String?
    ) {
        self.id = id
        self.$booking.id = bookingID
        self.$service.id = serviceID
        self.$user.id = userID
        self.rating = rating
        self.comment = comment
    }
}
