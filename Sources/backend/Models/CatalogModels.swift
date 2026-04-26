import Fluent
import Vapor

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
