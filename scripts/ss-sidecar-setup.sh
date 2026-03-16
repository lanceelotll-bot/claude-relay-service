#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$ROOT_DIR/config/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"
EXAMPLE_FILE="$CONFIG_DIR/config.example.json"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$EXAMPLE_FILE" ]; then
  echo "Missing template: $EXAMPLE_FILE"
  exit 1
fi

if [ -f "$CONFIG_FILE" ]; then
  read -r -p "Detected existing $CONFIG_FILE. Overwrite? [y/N] " OVERWRITE
  case "${OVERWRITE:-}" in
    y|Y|yes|YES) ;;
    *)
      echo "Keep existing config."
      exit 0
      ;;
  esac
fi

read -r -p "SS server host: " SS_SERVER
if [ -z "${SS_SERVER:-}" ]; then
  echo "SS server host is required."
  exit 1
fi

read -r -p "SS server port [443]: " SS_PORT
SS_PORT="${SS_PORT:-443}"
if ! [[ "$SS_PORT" =~ ^[0-9]+$ ]] || [ "$SS_PORT" -lt 1 ] || [ "$SS_PORT" -gt 65535 ]; then
  echo "Invalid port: $SS_PORT"
  exit 1
fi

read -r -p "SS method [aes-256-gcm]: " SS_METHOD
SS_METHOD="${SS_METHOD:-aes-256-gcm}"

read -r -s -p "SS password: " SS_PASSWORD
echo
if [ -z "${SS_PASSWORD:-}" ]; then
  echo "SS password is required."
  exit 1
fi

cat >"$CONFIG_FILE" <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "0.0.0.0",
      "listen_port": 1080
    },
    {
      "type": "http",
      "tag": "http-in",
      "listen": "0.0.0.0",
      "listen_port": 1081
    }
  ],
  "outbounds": [
    {
      "type": "shadowsocks",
      "tag": "ss-out",
      "server": "${SS_SERVER}",
      "server_port": ${SS_PORT},
      "method": "${SS_METHOD}",
      "password": "${SS_PASSWORD}"
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "ss-out"
  }
}
EOF

echo "Wrote SS sidecar config: $CONFIG_FILE"
echo "Next step: bash scripts/docker-up-ss.sh"
