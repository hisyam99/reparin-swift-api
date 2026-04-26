import Fluent
import Vapor

enum BookingStatus: String, Codable, CaseIterable {
    case requested
    case confirmed
    case inProgress = "in_progress"
    case completed
    case cancelled
}

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "email")
    var email: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Children(for: \.$user)
    var tokens: [UserToken]

    @Children(for: \.$customer)
    var bookings: [Booking]

    @Children(for: \.$user)
    var reviews: [Review]

    init() { }

    init(id: UUID? = nil, name: String, email: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.email = email
        self.passwordHash = passwordHash
    }
}

extension User: ModelAuthenticatable {
    static var usernameKey: KeyPath<User, FieldProperty<User, String>> { \User.$email }
    static var passwordHashKey: KeyPath<User, FieldProperty<User, String>> { \User.$passwordHash }

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

final class UserToken: Model, Content, @unchecked Sendable {
    static let schema = "user_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "value")
    var value: String

    @Parent(key: "user_id")
    var user: User

    @Timestamp(key: "expires_at", on: .none)
    var expiresAt: Date?

    init() { }

    init(id: UUID? = nil, value: String, userID: UUID, expiresAt: Date?) {
        self.id = id
        self.value = value
        self.$user.id = userID
        self.expiresAt = expiresAt
    }
}

extension UserToken: ModelTokenAuthenticatable {
    static var valueKey: KeyPath<UserToken, Field<String>> { \.$value }
    static var userKey: KeyPath<UserToken, Parent<User>> { \.$user }

    var isValid: Bool {
        guard let expiresAt else { return true }
        return expiresAt > Date()
    }
}

final class Category: Model, Content, @unchecked Sendable {
    static let schema = "categories"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @OptionalField(key: "description")
    var description: String?

    @Children(for: \.$category)
    var services: [ServiceListing]

    init() { }

    init(id: UUID? = nil, name: String, description: String?) {
        self.id = id
        self.name = name
        self.description = description
    }
}

final class ServiceProvider: Model, Content, @unchecked Sendable {
    static let schema = "service_providers"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "business_name")
    var businessName: String

    @OptionalField(key: "bio")
    var bio: String?

    @Field(key: "phone")
    var phone: String

    @Field(key: "city")
    var city: String

    @Field(key: "address")
    var address: String

    @Field(key: "is_active")
    var isActive: Bool

    @Children(for: \.$provider)
    var services: [ServiceListing]

    init() { }

    init(
        id: UUID? = nil,
        businessName: String,
        bio: String?,
        phone: String,
        city: String,
        address: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.businessName = businessName
        self.bio = bio
        self.phone = phone
        self.city = city
        self.address = address
        self.isActive = isActive
    }
}

final class ServiceListing: Model, Content, @unchecked Sendable {
    static let schema = "service_listings"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "provider_id")
    var provider: ServiceProvider

    @Parent(key: "category_id")
    var category: Category

    @Field(key: "title")
    var title: String

    @Field(key: "description")
    var description: String

    @Field(key: "base_price")
    var basePrice: Double

    @Field(key: "estimated_hours")
    var estimatedHours: Int

    @Field(key: "is_active")
    var isActive: Bool

    @Children(for: \.$service)
    var bookings: [Booking]

    @Children(for: \.$service)
    var reviews: [Review]

    init() { }

    init(
        id: UUID? = nil,
        providerID: UUID,
        categoryID: UUID,
        title: String,
        description: String,
        basePrice: Double,
        estimatedHours: Int,
        isActive: Bool = true
    ) {
        self.id = id
        self.$provider.id = providerID
        self.$category.id = categoryID
        self.title = title
        self.description = description
        self.basePrice = basePrice
        self.estimatedHours = estimatedHours
        self.isActive = isActive
    }
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
