Homeservice

A household management app: bills, shopping list, medicine stock, notes,
contractors (on a map) and home cameras (Imou).

| Part | Folder | Stack |
| --- | --- | --- |
| Server | `server/` | Go, chi, PostgreSQL |
| App | `client/` | Flutter, Riverpod, go_router |

---

## Running locally

### Every day

Two terminals, one short command each. Nothing else to start (a local
PostgreSQL is already running; with the Docker database see below):

```bash
cd server && make dev      # applies any new migrations, then runs the API
cd client && flutter run   # the app
```

`make dev` uses the demo cameras. For the real Imou account:
`make dev CAMERAS_DRIVER=` (with `IMOU_APP_ID` / `IMOU_APP_SECRET` set).

Migrations are only needed when someone adds a new file to
`server/migrations/`; `make dev` applies them for you, and does nothing when
there are none. You never set up the database again: its data stays.

### First time on a machine

Order: database → migrate → (seed, empty database only) → API → app.

### Server

The API needs a PostgreSQL database. Use **one** of these:

- **Local PostgreSQL** (default). Nothing to start if it is already running.
  Create the `homeservice` database and a `dev` role once; the Makefile's
  default DSN is
  `postgres://dev:devpass@localhost:5432/homeservice?sslmode=disable`.
- **Docker.** `cd server && docker compose up -d db` starts PostgreSQL 16 in a
  container. Use this when you want a throwaway database that is separate from
  your other projects (see the port note below).

Then:

```bash
cd server
make migrate                     # applies pending migrations only
make seed                        # EMPTY or throwaway database only, see below
CAMERAS_DRIVER=fake make run     # API at http://localhost:8080 with 3 demo cameras
```

Check that it is up: `curl localhost:8080/healthz`

- **Restart after every server code change.** `make run` does not reload.
- **Environment:** the API reads the variables of the shell it runs in (it does
  not read `server/.env`; that file is for `docker compose` only). Every one has
  a development default, so nothing needs setting to start. Set `JWT_SECRET`
  before putting it anywhere real. All variables are listed in
  [server/README.md](server/README.md).
- **`make migrate` is safe on a database with data:** it only applies the
  migrations that are not applied yet (`make migrate-status` lists them). Take a
  backup first if the data matters:
  `pg_dump "$DB_DSN" -Fc -f homeservice-$(date +%F).dump`.
- **Never run `make seed` on a database that holds real data.** It inserts the
  sample notes, chores, bills, purchases, medicine and contractors again on every
  run (no duplicate check) and resets the two dev accounts below. Never run
  `make migrate-reset` or `make fresh` there either: they drop every table.
- **DSN:** pass it explicitly when yours differs from the default:
  `make migrate DB_DSN='postgres://...'`.
- **Port 5432 already in use** (a local PostgreSQL is running) and you want the
  Docker database: publish the container on another host port and point the
  DSN at it, e.g.

  ```bash
  DB_HOST_PORT=5433 docker compose up -d db
  export DB_DSN='postgres://dev:devpass@localhost:5433/homeservice?sslmode=disable'
  make migrate && make seed
  CAMERAS_DRIVER=fake make run
  ```

  To keep it, set `DB_HOST_PORT=5433` and the `:5433` port in `DB_DSN` in
  `server/.env`. Always pass the DSN explicitly in this case, because the
  Makefile default points at port 5432. The user, password and database name in
  the DSN must match the `POSTGRES_USER`, `POSTGRES_PASSWORD` and `POSTGRES_DB`
  you start the container with.
- **Tests:** `go test ./... -race`

This machine's `homeservice` database was set up with `admin@example.com` /
`admin2026`. On a **new** database, `make seed` creates the two accounts below
(and sample data, so only on an empty or throwaway database). Either way,
**Create account** in the app makes a new one.

Dev accounts after `make seed` (local only):

| Role | Email | Password |
| --- | --- | --- |
| admin | `admin@example.com` | `admin2026` |
| member | `user@example.com` | `user2026` |

#### Optional features, switched on with env

| Feature | Variables | When not set |
| --- | --- | --- |
| Real Imou cameras | `IMOU_APP_ID`, `IMOU_APP_SECRET`, `IMOU_REGION=sg` (leave out `CAMERAS_DRIVER=fake`) | The cameras screen says the feature is not enabled |
| Contractor search on Google | `GOOGLE_PLACES_API_KEY` | Contractors shows only the saved ones |

The fake driver (`CAMERAS_DRIVER=fake`) lets you try the screens and controls
without an Imou account. Its live picture is a public test stream; change it
with `CAMERAS_FAKE_STREAM_URL`.

### App (Flutter)

```bash
open -a Simulator                # open the iOS simulator (or plug in a device)
cd client
flutter pub get
flutter run                      # several devices: flutter devices, then flutter run -d <id>
```

- **API address:** the `API_BASE_URL` key in `client/.env.development`.

  | Running on | Value |
  | --- | --- |
  | iOS simulator | `http://127.0.0.1:8080/api/v1` |
  | Android emulator | `http://10.0.2.2:8080/api/v1` |
  | Physical device | `http://<your machine's LAN IP>:8080/api/v1` |

- **Languages:** Thai and English. The app follows the device language and can
  be switched from the translate button on the home screen. Strings live in
  `client/lib/l10n/app_en.arb` (template) and `app_th.arb`, which must have the
  same keys. Regenerate the code with `flutter gen-l10n` (it also runs on
  `flutter pub get` and `flutter run`).
- **Check and test:** `flutter analyze` and `flutter test`

---

## Project status

The project is **temporarily on hold** as of 7 March 2026.

There is no fixed date for resuming development. The code is in a working
state as of the latest commit.
