@testable import backend
import VaporTesting
import Testing
import Fluent

@Suite("App Tests with DB", .serialized)
struct backendTests {
    private func withApp(_ test: (Application) async throws -> ()) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await app.autoMigrate()
            try await test(app)
            try await app.autoRevert()
        } catch {
            try? await app.autoRevert()
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
    
    @Test("Health Route")
    func healthRoute() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "health", afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }
    }

    @Test("Register and Login")
    func registerAndLogin() async throws {
        try await withApp { app in
            let registerPayload = RegisterRequest(name: "Hisyam", email: "hisyam@mail.com", password: "password123")

            try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
                try req.content.encode(registerPayload)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let auth = try res.content.decode(AuthResponse.self)
                #expect(!auth.token.isEmpty)
                #expect(auth.user.email == registerPayload.email)
            })

            try await app.testing().test(.POST, "api/v1/auth/login", beforeRequest: { req in
                try req.content.encode(LoginRequest(email: registerPayload.email, password: registerPayload.password))
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let auth = try res.content.decode(AuthResponse.self)
                #expect(!auth.token.isEmpty)
            })
        }
    }

    @Test("List services and create booking")
    func servicesAndBooking() async throws {
        try await withApp { app in
            let registerPayload = RegisterRequest(name: "Booker", email: "booker@mail.com", password: "password123")
            let token = try await register(registerPayload, app: app)

            let serviceID = try #require(try await ServiceListing.query(on: app.db).first()?.id)

            try await app.testing().test(.GET, "api/v1/services", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let services = try res.content.decode([ServiceResponse].self)
                #expect(!services.isEmpty)
            })

            try await app.testing().test(.POST, "api/v1/bookings", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(
                    CreateBookingRequest(
                        serviceID: serviceID,
                        scheduledAt: Date().addingTimeInterval(86_400),
                        customerNote: "Datang sore"
                    )
                )
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let booking = try res.content.decode(BookingResponse.self)
                #expect(booking.status == .requested)
            })
        }
    }

    private func register(_ payload: RegisterRequest, app: Application) async throws -> String {
        var token = ""
        try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
            try req.content.encode(payload)
        }, afterResponse: { res async throws in
            let auth = try res.content.decode(AuthResponse.self)
            token = auth.token
        })
        return token
    }
}
