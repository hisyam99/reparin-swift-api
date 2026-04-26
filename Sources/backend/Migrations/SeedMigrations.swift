import Fluent

struct SeedMarketplaceData: AsyncMigration {
    func prepare(on database: any Database) async throws {
        if try await Category.query(on: database).first() != nil {
            return
        }

        let categories = [
            Category(name: "Phone Repair", description: "Perbaikan smartphone dan tablet."),
            Category(name: "Laptop Service", description: "Upgrade, cleaning, dan troubleshooting laptop."),
            Category(name: "Console Repair", description: "Servis perangkat gaming console.")
        ]
        try await categories.create(on: database)

        let providers = [
            ServiceProvider(
                businessName: "FixNow Gadget Center",
                bio: "Spesialis kerusakan motherboard dan water damage.",
                phone: "081234567890",
                city: "Jakarta",
                address: "Jl. Sudirman No. 100"
            ),
            ServiceProvider(
                businessName: "LaptopCare Studio",
                bio: "Fokus pada performa dan thermal tuning laptop.",
                phone: "081298765432",
                city: "Bandung",
                address: "Jl. Asia Afrika No. 45"
            )
        ]
        try await providers.create(on: database)

        guard
            let phoneCategoryID = categories.first?.id,
            let laptopCategoryID = categories.dropFirst().first?.id,
            let firstProviderID = providers.first?.id,
            let secondProviderID = providers.dropFirst().first?.id
        else {
            return
        }

        let services = [
            ServiceListing(
                providerID: firstProviderID,
                categoryID: phoneCategoryID,
                title: "Ganti LCD iPhone/Android",
                description: "Penggantian layar retak dengan garansi 30 hari.",
                basePrice: 350_000,
                estimatedHours: 3
            ),
            ServiceListing(
                providerID: secondProviderID,
                categoryID: laptopCategoryID,
                title: "Cleaning + Thermal Paste Laptop",
                description: "Pembersihan menyeluruh dan penggantian thermal paste.",
                basePrice: 250_000,
                estimatedHours: 2
            )
        ]
        try await services.create(on: database)
    }

    func revert(on database: any Database) async throws {
        try await Review.query(on: database).delete()
        try await BookingStatusHistory.query(on: database).delete()
        try await Booking.query(on: database).delete()
        try await ServiceListing.query(on: database).delete()
        try await ServiceProvider.query(on: database).delete()
        try await Category.query(on: database).delete()
    }
}
