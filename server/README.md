# Homeservice Backend

A personal home management API built with Go. Manage bills, purchases, notes, chores, medicine stock, and contractors — all in one place.

---

## Tech Stack

- **Language:** Go 1.24+
- **Router:** Chi
- **Database:** PostgreSQL 16
- **Auth:** JWT (HS256)
- **Storage:** Local / Cloudflare R2
- **Migration:** Goose
- **Container:** Docker + Docker Compose

---

## Project Structure

```
homeservice-backend/
├── cmd/
│   ├── api/          # Main server entrypoint
│   ├── migrate/      # Migration runner
│   └── seed/         # Database seeder
├── internal/
│   ├── auth/         # JWT auth middleware
│   ├── bills/        # Bills module
│   ├── chores/       # Chores module
│   ├── config/       # App configuration
│   ├── contractors/  # Contractors module
│   ├── db/           # Database connection
│   ├── files/        # File upload module
│   ├── health/       # Health check handlers
│   ├── httpx/        # HTTP helpers & middleware
│   ├── medicine/     # Medicine stock module
│   ├── notes/        # Notes module
│   ├── purchases/    # Purchases module
│   ├── storage/      # Storage adapters (Local/R2)
│   └── user/         # User & auth module
├── migrations/       # SQL migration files
├── .env              # Environment variables (not committed)
├── .env.example      # Environment variables template
├── docker-compose.yml
├── Dockerfile
└── Makefile
```

---

## Getting Started

### Prerequisites

- Go 1.24+
- PostgreSQL 16 (or Docker)
- Make (optional)

### 1. Clone & Setup

```bash
git clone https://github.com/iMookatayou/homeservice-backend.git
cd homeservice-backend
cp .env.example .env
```

Edit `.env` with your configuration.

### 2. Start Database

```bash
docker-compose up -d db
```

### 3. Run Migrations

```bash
go run ./cmd/migrate -cmd=up
```

### 4. Seed Database

```bash
go run ./cmd/seed
```

Dev accounts (local only — never seed a production database):

| Role | Email | Password |
|---|---|---|
| admin | `admin@example.com` | `admin2026` |
| member | `user@example.com` | `user2026` |

### 5. Start Server

```bash
go run ./cmd/api
```

Server will start at `http://localhost:8080`

---

## Docker

### Run everything with Docker Compose

```bash
docker-compose up -d
```

This will start both the database and the API server.

---

## Makefile Commands

```bash
make migrate          # Run migrations up
make migrate-down     # Rollback last migration
make migrate-reset    # Reset all migrations
make migrate-status   # Show migration status
make seed             # Seed database
make fresh            # Reset + migrate + seed
make run              # Run API server
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_PORT` | Server port | `8080` |
| `DB_DSN` | PostgreSQL connection string | `postgres://dev:devpass@localhost:5432/homeservice?sslmode=disable` |
| `JWT_SECRET` | JWT signing secret | `change-me` |
| `CORS_ALLOW_ORIGIN` | Allowed CORS origin | `*` |
| `STORAGE_BACKEND` | Storage backend (`local` or `r2`) | `local` |
| `LOCAL_STORAGE_DIR` | Local storage directory | `./data/uploads` |
| `PUBLIC_BASE_URL` | Public URL for file access | `http://localhost:8080/static` |
| `R2_ACCOUNT_ID` | Cloudflare R2 Account ID | - |
| `R2_ACCESS_KEY_ID` | Cloudflare R2 Access Key | - |
| `R2_SECRET_ACCESS_KEY` | Cloudflare R2 Secret Key | - |
| `R2_BUCKET` | Cloudflare R2 Bucket name | - |
| `R2_PUBLIC_URL` | Cloudflare R2 Public URL | - |
| `GOOGLE_PLACES_API_KEY` | Google Places API (New) key. Empty = Google lookups off | - |
| `GOOGLE_PLACES_BASE_URL` | Override Google's endpoint (tests / local fake) | Google production |
| `GOOGLE_PLACES_DAILY_LIMIT` | Outbound Google calls per day, all users (0 = unlimited) | `300` |
| `GOOGLE_PLACES_RATE_PER_MIN` | Google-backed requests per user per minute | `20` |
| `GOOGLE_PLACES_MAX_RADIUS_M` | Largest search radius accepted (Google's own cap is 50000) | `20000` |
| `GOOGLE_PLACES_ALLOW_ALL_TRADES` | Allow a search with no trade and no text (fans out to 4 calls) | `false` |

---

## API Endpoints

### Auth (Public)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Register new user |
| POST | `/api/v1/auth/login` | Login |
| POST | `/api/v1/auth/logout` | Logout |
| POST | `/api/v1/auth/forgot-password` | Request password reset |
| POST | `/api/v1/auth/reset-password` | Reset password |

### User (Auth Required)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/me` | Get current user |
| PATCH | `/api/v1/me` | Update profile |
| POST | `/api/v1/me/password` | Change password |

### Notes
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/notes` | List notes |
| POST | `/api/v1/notes` | Create note |
| GET | `/api/v1/notes/:id` | Get note |
| PUT | `/api/v1/notes/:id` | Update note |
| DELETE | `/api/v1/notes/:id` | Delete note |
| POST | `/api/v1/notes/:id/pin` | Pin note |
| POST | `/api/v1/notes/:id/unpin` | Unpin note |
| POST | `/api/v1/notes/:id/done` | Mark done |
| POST | `/api/v1/notes/:id/undone` | Mark undone |

### Chores
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/chores` | List chores |
| POST | `/api/v1/chores` | Create chore |
| POST | `/api/v1/chores/:id/claim` | Claim chore |
| POST | `/api/v1/chores/:id/complete` | Complete chore |
| DELETE | `/api/v1/chores/:id` | Delete chore |

### Bills
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/bills` | List bills |
| POST | `/api/v1/bills` | Create bill |
| GET | `/api/v1/bills/:id` | Get bill |
| PATCH | `/api/v1/bills/:id` | Update bill |
| DELETE | `/api/v1/bills/:id` | Delete bill |
| POST | `/api/v1/bills/:id/pay` | Mark as paid |
| GET | `/api/v1/bills/summary` | Bills summary |

### Purchases
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/purchases` | List purchases |
| POST | `/api/v1/purchases` | Create purchase |
| GET | `/api/v1/purchases/:id` | Get purchase |
| PATCH | `/api/v1/purchases/:id` | Update purchase |
| DELETE | `/api/v1/purchases/:id` | Delete purchase |
| POST | `/api/v1/purchases/:id/claim` | Claim purchase |
| POST | `/api/v1/purchases/:id/progress` | Progress status |
| POST | `/api/v1/purchases/:id/cancel` | Cancel purchase |

### Medicine
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/medicine` | List medicine |
| POST | `/api/v1/medicine` | Add medicine |
| GET | `/api/v1/medicine/:id` | Get medicine |
| PATCH | `/api/v1/medicine/:id` | Update medicine |
| DELETE | `/api/v1/medicine/:id` | Delete medicine |
| POST | `/api/v1/medicine/:id/stock` | Adjust stock |
| GET | `/api/v1/medicine/:id/alert` | Get alert |
| PUT | `/api/v1/medicine/:id/alert` | Set alert |
| GET | `/api/v1/medicine/low-stock` | List low stock |
| GET | `/api/v1/medicine/expiring` | List expiring soon |
| GET | `/api/v1/medicine/expired` | List expired |

### Contractors
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/contractors` | List contractors |
| POST | `/api/v1/contractors` | Add contractor |
| GET | `/api/v1/contractors/:id` | Get contractor |
| PATCH | `/api/v1/contractors/:id` | Update contractor |
| DELETE | `/api/v1/contractors/:id` | Delete contractor |
| POST | `/api/v1/contractors/:id/favorite` | Toggle favorite |
| GET | `/api/v1/contractors/favorites` | List favorites |

### Places (Google, optional)
Off unless `GOOGLE_PLACES_API_KEY` is set; then Google-backed calls answer
`503 google_places_disabled`. Auth required.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/places/status` | `{enabled, daily_used, daily_limit}`. Always answers, costs no Google call |
| GET | `/api/v1/places/nearby?lat=&lng=&radius=&type=&q=&limit=` | Businesses near a point, nearest first. Needs `type` (`electrician`, `plumber`, `carpenter`, `hvac`) or `q`; each result has `starred` |
| GET | `/api/v1/places/starred?lat=&lng=` | The household's starred places, looked up by id (1 cheap Google call each, max 20) |
| GET | `/api/v1/places/:place_id` | Phone, rating, website, opening status for one place |
| PUT | `/api/v1/places/:place_id/star` | Star a place. Body `{"trade":"plumber"}` is optional. Works with Google off |
| DELETE | `/api/v1/places/:place_id/star` | Remove the star |

How the load is kept down:
- A search without a trade or text is refused (`400 type_or_q_required`), so
  "browse all" never reaches Google.
- One search = one Google call; results per search default to 20, max 40;
  radius is capped (default 20 km).
- Per user: 20 requests/min (`429 rate_limited`). Across everyone: a daily
  call budget (`429 daily_limit`), reset at midnight Asia/Bangkok. It is
  in-memory, so a restart resets it; move it to the database if it ever has
  to be a hard financial limit across several instances.
- A fan-out is reserved all-or-nothing, so a refused request never half-spends.

Notes: only a `place_id` (and our own trade label) is stored, never Google's
content; the list call requests cheap fields and phone/rating/website is a
separate call because those fields bill at a higher rate; Google's terms don't
allow these results on a non-Google map, so the app lists them without pinning
them on OpenStreetMap.

### Files
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/uploads` | Upload file |
| GET | `/api/v1/files/:id` | Get file |
| DELETE | `/api/v1/files/:id` | Delete file |

### Health
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/healthz` | Liveness check |
| GET | `/readyz` | Readiness check |

---

## Database Schema

| Table | Description |
|-------|-------------|
| `users` | User accounts with roles |
| `notes` | Notes and tasks |
| `chores` | Household chores |
| `bills` | Monthly bills |
| `purchases` | Purchase requests |
| `medicine_items` | Medicine stock |
| `medicine_alerts` | Medicine alerts |
| `contractors` | Contractors list |
| `files` | Uploaded files |
| `password_resets` | Password reset tokens |

---

## License

Private — for personal home use only.