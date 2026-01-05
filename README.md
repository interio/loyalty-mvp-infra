# Loyalty MVP Infra

This repo owns local orchestration for the stack (backend, admin UI, Postgres). Place this folder alongside `loyalty-mvp-backend` and `loyalty-mvp-admin-ui`.

## Getting started
1) Copy `.env.example` to `.env` and adjust values if needed.
2) Bring up dependencies:
```
./dev.sh up           # Postgres only, for running the API locally with dotnet watch
./dev.sh stack        # Backend + admin-ui + Postgres via Docker
```
3) Local API with hot reload:
```
./dev.sh watch-api    # starts Postgres via Docker and runs dotnet watch in ../loyalty-mvp-backend
```
4) Stop services: `./dev.sh down`. Tail logs: `./dev.sh logs`.

## Sample data seeding
With the backend running (via `./dev.sh stack` or `./dev.sh watch-api`), seed demo data:
```
./seed.sh
```
What it does:
- Creates one tenant, one customer, and two users (administrator + owner).
- Adds manual adjustments + redemptions to the ledger.
- Upserts 10 products (beer/cider SKUs).
- Applies three invoices via the integration API (points rules run asynchronously).

## Compose summary
- backend: builds from `../loyalty-mvp-backend/Dockerfile`, exposed on `8080`.
- admin-ui: builds from `../loyalty-mvp-admin-ui/Dockerfile`, exposed on `3000` (uses `API_BASE_URL`).
- postgres: `postgres:16`, data persisted in volume `pgdata`.
