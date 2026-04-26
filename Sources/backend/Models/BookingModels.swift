import Fluent
import Vapor

enum BookingStatus: String, Codable, CaseIterable {
    case requested
    case confirmed
    case inProgress = "in_progress"
    case completed
    case cancelled
}

final class Booking: Model, Content, @unchecked Sendable {
    static let schema = "bookings"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "customer_id")
    var customer: User

    @Parent(key: "service_id")
    var service: ServiceListing

    @Enum(key: "status")
    var status: BookingStatus

    @Field(key: "scheduled_at")
    var scheduledAt: Date

    @OptionalField(key: "customer_note")
    var customerNote: String?

    @Field(key: "quoted_price")
    var quotedPrice: Double

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Children(for: \.$booking)
    var statusHistory: [BookingStatusHistory]

    init() { }

    init(
        id: UUID? = nil,
        customerID: UUID,
        serviceID: UUID,
        status: BookingStatus,
        scheduledAt: Date,
        customerNote: String?,
        quotedPrice: Double
    ) {
        self.id = id
        self.$customer.id = customerID
        self.$service.id = serviceID
        self.status = status
        self.scheduledAt = scheduledAt
        self.customerNote = customerNote
        self.quotedPrice = quotedPrice
    }
}

final class BookingStatusHistory: Model, Content, @unchecked Sendable {
    static let schema = "booking_status_history"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "booking_id")
    var booking: Booking

    @Enum(key: "status")
    var status: BookingStatus

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil, bookingID: UUID, status: BookingStatus) {
        self.id = id
        self.$booking.id = bookingID
        self.status = status
    }
}
