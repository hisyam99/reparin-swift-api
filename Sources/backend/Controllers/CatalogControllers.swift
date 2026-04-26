import Fluent
import Vapor

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
