# Loyalty MVP Infra

This repo owns local orchestration for the stack (backend, admin UI, Postgres). Place this folder alongside `loyalty-mvp-backend` and `loyalty-mvp-admin-ui`.

## Getting started
1) Copy `.env.example` to `.env` and adjust values if needed.
   - Required for backend: `ConnectionStrings__Default`.
   - `API_BASE_URL` is used by `seed.sh` as a fallback backend URL. For host-run scripts, prefer `BACKEND_URL=http://localhost:8080`.
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

## Running backend/admin commands in containers
When you want to run `dotnet`/`npm` without local SDK installs, run them in containers attached to the infra network.

Backend migrations example (run from parent folder that contains all three repos):
```
cd ..
docker run --rm \
  --network=loyalty-mvp-infra_loyalty \
  --env-file loyalty-mvp-infra/.env \
  -e ConnectionStrings__Default="Host=postgres;Port=5432;Database=loyalty;Username=loyalty;Password=loyalty" \
  -v "$(pwd)/loyalty-mvp-backend:/src" \
  -w /src \
  mcr.microsoft.com/dotnet/sdk:8.0 \
  sh -lc "dotnet restore LoyaltyMvp.sln && dotnet tool install --tool-path /tmp/dotnet-tools dotnet-ef && /tmp/dotnet-tools/dotnet-ef database update --context IntegrationDbContext --project src/api --startup-project src/api"
```

Admin UI build example:
```
cd ..
docker run --rm \
  -v "$(pwd)/loyalty-mvp-admin-ui:/src" \
  -w /src \
  node:20-alpine \
  sh -lc "npm install && npm run build"
```

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
BACKEND_URL=http://localhost:8080 ./seed.sh
```
Requires Python 3 available as `python3`.
`seed.sh` expects an existing tenant (OPCO/market) and uses `SEED_TENANT_ID` (default: `0eb3173e-df9f-4604-a706-21cb97ba3530`).
If backend is running via local `watch-api` (default launch profile `5137`), pass an explicit URL:
```
BACKEND_URL=http://localhost:5137 ./seed.sh
```
Use `http://localhost:8080` instead if you overrode `ASPNETCORE_URLS` to `8080`.
What it does:
- Uses the configured tenant (OPCO/market), creates one customer, and two users (administrator + owner).
- Adds manual adjustments + redemptions to the ledger.
- Inserts sample points rules (spend + SKU quantity) for the tenant.
- Upserts 10 products (beer/cider SKUs) across two distributors within the tenant.
- Applies three invoices via the integration API (points rules run asynchronously).

## Compose summary
- backend: builds from `../loyalty-mvp-backend/Dockerfile`, exposed on `8080`.
- admin-ui: builds from `../loyalty-mvp-admin-ui/Dockerfile`, exposed on `3000` (Nginx proxies `/graphql` and `/api/*` to the backend service).
- postgres: `postgres:16`, data persisted in volume `pgdata`.
