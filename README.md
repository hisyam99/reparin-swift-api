# Reparin API (Swift)

Reparin API build with Swift (Vapor + Fluent + PostgreSQL).

## Getting Started

### Environment (.env)

Default koneksi database sudah diarahkan ke:

- `DATABASE_HOST=localhost`
- `DATABASE_PORT=5432`
- `DATABASE_USERNAME=postgres`
- `DATABASE_PASSWORD=postgres`
- `DATABASE_NAME=hisyam-swift1`

Loader `.env` dibaca otomatis saat app startup (`entrypoint.swift`), jadi buat/ubah file:

- `backend/.env`

### Build

```bash
swift build
```

### Run

```bash
swift run
```

### Migrate

```bash
swift run backend migrate
```

### Test

```bash
swift test
```

## API Contract (v1)

Base URL: `http://127.0.0.1:8080/api/v1`

### Health

- `GET /health`

### Auth

- `POST /auth/register`
  - body:
    - `name: String`
    - `email: String`
    - `password: String (min 8)`
  - response:
    - `token`
    - `user { id, name, email }`
- `POST /auth/login`
  - body:
    - `email`
    - `password`
  - response:
    - `token`
    - `user`
- `GET /auth/me` (Bearer token)
  - response:
    - `id, name, email`

### Categories (Public)

- `GET /categories`
  - response array:
    - `id, name, description`

### Providers (Public)

- `GET /providers`
  - response array:
    - `id, businessName, bio, phone, city, address`

### Services (Public)

- `GET /services`
  - query optional:
    - `q` (search di title/description)
    - `categoryID` (UUID)
    - `city` (substring match)
  - response array:
    - `id, title, description, basePrice, estimatedHours`
    - nested `category`
    - nested `provider`
- `GET /services/:serviceID`
  - response:
    - detail service format sama seperti list item

### Bookings (Bearer token required)

- `GET /bookings`
  - response array:
    - `id, status, scheduledAt, customerNote, quotedPrice, service`
- `GET /bookings/:bookingID`
  - response:
    - detail booking
- `POST /bookings`
  - body:
    - `serviceID: UUID`
    - `scheduledAt: Date`
    - `customerNote: String?`
  - response:
    - booking created dengan status `requested`
- `POST /bookings/:bookingID/cancel`
  - hanya valid saat status `requested` atau `confirmed`
  - response:
    - booking status jadi `cancelled`

### Reviews

- `GET /reviews` (Public)
  - query optional:
    - `serviceID`
    - `providerID`
  - response array:
    - `id, bookingID, serviceID, userID, rating, comment, createdAt`
- `POST /reviews` (Bearer token)
  - body:
    - `bookingID: UUID`
    - `rating: Int (1...5)`
    - `comment: String?`
  - rule:
    - hanya booking milik user yang status `completed`
    - satu booking hanya satu review

## Seed Data

Migration `SeedMarketplaceData` akan mengisi data awal:

- 3 kategori
- 2 service provider
- 2 service listing

Seed ini untuk mempercepat pengembangan mobile di fase berikutnya.

## See more

- [Vapor Website](https://vapor.codes)
- [Vapor Documentation](https://docs.vapor.codes)
- [Vapor GitHub](https://github.com/vapor)
- [Vapor Community](https://github.com/vapor-community)
