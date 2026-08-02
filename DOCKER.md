# Running with Docker

## Quickstart

```bash
docker-compose up --build
```

That's it. No manual config needed - a working `.env` with sane defaults is
already included. Once all three services report healthy:

- **App**: http://localhost:8080
- **Backend API**: http://localhost:3000
- **Postgres**: localhost:5432 (user `app_user` / db `church_db`)

To stop everything: `docker-compose down`. To also wipe the database:
`docker-compose down -v`.

## What's running

| Service    | Image                | What it does                                   |
|------------|-----------------------|-------------------------------------------------|
| `db`       | postgres:16-alpine     | Database, seeded on first boot from `db/init.sql` |
| `backend`  | built from `backend/`  | Node/Express API                               |
| `frontend` | built from `frontend/` | Flutter web build, served by nginx             |

Startup order is enforced by healthchecks: `frontend` won't start until
`backend` reports healthy, and `backend` won't start until `db` does.

## Configuration

All configuration lives in `.env` at the project root (copied from
`.env.example`) - `docker-compose` loads it automatically. Nothing is
hardcoded in the app source or in `docker-compose.yml` itself. You generally
won't need to change anything, but you can override:

| Variable            | Default                   | What it controls                                  |
|----------------------|----------------------------|-----------------------------------------------------|
| `POSTGRES_DB`         | `church_db`                | Database name                                       |
| `POSTGRES_USER`       | `app_user`                 | Database user                                       |
| `POSTGRES_PASSWORD`   | `root`                     | Database password                                   |
| `POSTGRES_PORT`       | `5432`                     | Host port for Postgres                              |
| `BACKEND_PORT`        | `3000`                     | Host port for the API                               |
| `FRONTEND_PORT`       | `8080`                     | Host port for the web app                           |
| `API_BASE_URL`        | `http://localhost:3000`    | Backend URL baked into the Flutter web build         |

`API_BASE_URL` only needs to change if you're accessing the frontend from a
different machine than the one running Docker (e.g. deploying to a server,
or opening the app from another device on your network) - point it at
wherever *that machine* can reach the backend from a browser.

If you change `.env`, rebuild so the change takes effect:

```bash
docker-compose up --build
```

(Editing `.env` alone doesn't retroactively change an already-built image -
`API_BASE_URL` in particular is compiled into the frontend's static JS at
build time, not read at container runtime.)

## Useful commands

```bash
# Rebuild a single service after code changes
docker-compose up --build backend
docker-compose up --build frontend

# Force a clean rebuild, ignoring layer cache
docker-compose build --no-cache

# Tail logs
docker-compose logs -f backend

# Check service health
docker-compose ps

# Reset the database (drops all data, re-runs db/init.sql on next start)
docker-compose down -v
```

## Notes

- `db/init.sql` is a cleaned-up, idempotent version of `church_db.session.sql`
  (which is a raw psql session log, not a valid init script) - it reproduces
  the same schema and seed data so Postgres can run it automatically on
  first boot.
- The backend exposes `GET /health` (checks DB connectivity) purely for
  Docker's healthcheck - it's not used by the app UI.
