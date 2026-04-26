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
