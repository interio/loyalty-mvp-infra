# Loyalty MVP Infra

This repo owns local orchestration for the stack (backend, admin UI, Postgres). Place this folder alongside `loyalty-mvp-backend` and `loyalty-mvp-admin-ui`.

## Getting started
1) Copy `.env.example` to `.env` and adjust values if needed.
   - Required for backend: `ConnectionStrings__Default`.
   - Compose default `API_BASE_URL=http://backend:8080` is intended for container-to-container calls.
   - Optional for backend CORS: `ALLOWED_ORIGINS` (comma-separated origins or `*`).
2) Bring up dependencies:
```
./dev.sh up           # Postgres only, for running the API locally with dotnet watch
./dev.sh stack        # Backend + admin-ui + Postgres via Docker
```
3) Local API with hot reload:
```
./dev.sh watch-api    # starts Postgres via Docker and runs dotnet watch in ../loyalty-mvp-backend
```
Note:
- The backend needs `ConnectionStrings__Default` in the environment. If you're using `.env`, run `set -a; source .env; set +a` before `./dev.sh watch-api`.
- `dotnet watch` uses backend launch settings by default (`http://localhost:5137`). To run local watch mode on `8080`, set `ASPNETCORE_URLS=http://localhost:8080` before `./dev.sh watch-api`.
4) Stop services: `./dev.sh down`. Tail logs: `./dev.sh logs`.

## Build the stack in Docker (no local dotnet/node needed)
If you want Docker to build both images (useful on macOS without dotnet installed):
```
./dev.sh down   # optional: stop existing stack
./dev.sh build  # builds backend and admin-ui images via Docker Compose
./dev.sh stack  # starts backend + admin-ui + Postgres
```
You can skip `build` if nothing changed and you just want to (re)start with existing images.

## Sample data seeding
With the backend running (via `./dev.sh stack` or `./dev.sh watch-api`), seed demo data:
```
./seed.sh
```
Requires Python 3 available as `python3`.
If backend is running via local `watch-api` (not Compose backend service), pass an explicit URL:
```
BACKEND_URL=http://localhost:5137 ./seed.sh
```
Use `http://localhost:8080` instead if you overrode `ASPNETCORE_URLS` to `8080`.
What it does:
- Creates one tenant, one customer, and two users (administrator + owner).
- Adds manual adjustments + redemptions to the ledger.
- Inserts sample points rules (spend + SKU quantity) for the tenant.
- Upserts 10 products (beer/cider SKUs).
- Applies three invoices via the integration API (points rules run asynchronously).

## Compose summary
- backend: builds from `../loyalty-mvp-backend/Dockerfile`, exposed on `8080`.
- admin-ui: builds from `../loyalty-mvp-admin-ui/Dockerfile`, exposed on `3000` (Nginx proxies `/graphql` and `/api/*` to the backend service).
- postgres: `postgres:16`, data persisted in volume `pgdata`.
