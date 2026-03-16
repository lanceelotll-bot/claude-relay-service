#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/sing-box/config.json"
EXAMPLE_FILE="$ROOT_DIR/config/sing-box/config.example.json"

cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install Docker first."
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  if [ -f "$EXAMPLE_FILE" ]; then
    cp "$EXAMPLE_FILE" "$CONFIG_FILE"
    echo "Created $CONFIG_FILE from template."
    echo "Please run: bash scripts/ss-sidecar-setup.sh"
    exit 1
  fi
  echo "Missing SS sidecar config template: $EXAMPLE_FILE"
  exit 1
fi

if rg -q "REPLACE_SS_SERVER|REPLACE_SS_PASSWORD" "$CONFIG_FILE"; then
  echo "Please finish SS config first: $CONFIG_FILE"
  echo "Run: bash scripts/ss-sidecar-setup.sh"
  exit 1
fi

echo "Validating sing-box config..."
if ! docker run --rm -v "$CONFIG_FILE:/etc/sing-box/config.json:ro" \
  ghcr.io/sagernet/sing-box:latest check -c /etc/sing-box/config.json >/dev/null; then
  echo "Invalid sing-box config: $CONFIG_FILE"
  echo "Fix it first or regenerate with: bash scripts/ss-sidecar-setup.sh"
  exit 1
fi

docker compose -f docker-compose.yml -f docker-compose.ss.yml up -d --build

echo
echo "SS sidecar stack started."
echo "For account proxy config in CRS:"
echo "  type: socks5"
echo "  host: ss-sidecar"
echo "  port: 1080"
echo
echo "Host-side debug proxy:"
echo "  socks5://127.0.0.1:${SS_SIDECAR_SOCKS_PORT:-11080}"
echo "  http://127.0.0.1:${SS_SIDECAR_HTTP_PORT:-11081}"
echo
echo "Run connectivity test:"
echo "  bash scripts/ss-sidecar-test.sh"
echo
echo "For long-running stability (auto-heal):"
echo "  bash scripts/ss-sidecar-watchdog.sh"
