#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/../loyalty-mvp-backend"
ADMIN_DIR="$ROOT_DIR/../loyalty-mvp-admin-ui"
ENV_FILE="$ROOT_DIR/.env"
ENV_EXAMPLE="$ROOT_DIR/.env.example"

compose() {
  docker compose -f "$ROOT_DIR/docker-compose.yml" "$@"
}

ensure_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "Created $ENV_FILE from .env.example; edit it before re-running if needed."
  fi
}

usage() {
  cat <<'EOF'
Usage: ./dev.sh [command]
Commands:
  up           Start Postgres only (for local dotnet watch against DB)
  stack        Start backend + admin-ui + Postgres via Docker Compose
  build        Build backend and admin-ui images (uses Docker, no local dotnet/node needed)
  watch-api    Start Postgres (Compose) and run dotnet watch for the API locally
  logs         Tail Compose logs
  down         Stop and remove Compose services
EOF
}

CMD="${1:-up}"
shift || true

case "$CMD" in
  up)
    ensure_env
    compose --env-file "$ENV_FILE" up -d postgres
    ;;
  stack)
    ensure_env
    compose --env-file "$ENV_FILE" up -d
    ;;
  build)
    ensure_env
    compose --env-file "$ENV_FILE" build backend admin-ui
    ;;
  watch-api)
    ensure_env
    compose --env-file "$ENV_FILE" up -d postgres
    (cd "$BACKEND_DIR" && dotnet watch --project src/api/Loyalty.Api.csproj)
    ;;
  logs)
    ensure_env
    compose --env-file "$ENV_FILE" logs -f --tail=200
    ;;
  down)
    compose down
    ;;
  *)
    usage
    exit 1
    ;;
esac
