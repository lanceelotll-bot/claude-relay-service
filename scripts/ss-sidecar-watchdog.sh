#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILES=(-f docker-compose.yml -f docker-compose.ss.yml)
SERVICE_NAME="ss-sidecar"
AUTO_RESTART="${AUTO_RESTART_SS_SIDECAR:-true}"
TEST_TARGET="${SS_WATCHDOG_TEST_URL:-https://api.anthropic.com/v1/messages}"

is_enabled() {
  local raw="${1:-}"
  local normalized
  normalized="$(echo "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$normalized" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "[watchdog] Docker is required."
  exit 1
fi

if ! docker compose "${COMPOSE_FILES[@]}" ps --status running "$SERVICE_NAME" | grep -q "$SERVICE_NAME"; then
  echo "[watchdog] $SERVICE_NAME is not running."
  if is_enabled "$AUTO_RESTART"; then
    echo "[watchdog] starting $SERVICE_NAME ..."
    docker compose "${COMPOSE_FILES[@]}" up -d "$SERVICE_NAME"
  else
    exit 1
  fi
fi

if bash "$ROOT_DIR/scripts/ss-sidecar-test.sh" "$TEST_TARGET"; then
  echo "[watchdog] proxy test passed."
  exit 0
fi

echo "[watchdog] proxy test failed."
if ! is_enabled "$AUTO_RESTART"; then
  exit 1
fi

echo "[watchdog] restarting $SERVICE_NAME ..."
docker compose "${COMPOSE_FILES[@]}" restart "$SERVICE_NAME"
sleep 3

if bash "$ROOT_DIR/scripts/ss-sidecar-test.sh" "$TEST_TARGET"; then
  echo "[watchdog] proxy recovered after restart."
  exit 0
fi

echo "[watchdog] proxy still unavailable after restart."
exit 1
