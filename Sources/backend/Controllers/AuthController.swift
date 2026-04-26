import Fluent
import Vapor

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
