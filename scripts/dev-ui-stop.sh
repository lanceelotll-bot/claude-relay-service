#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT_DIR/pids/dev-ui.pid"

PID=""

if [ -f "$PID_FILE" ]; then
  PID="$(cat "$PID_FILE")"
else
  PID="$(lsof -tiTCP:3001 -sTCP:LISTEN 2>/dev/null | head -n 1 || true)"
fi

if [ -n "$PID" ] && kill -0 "$PID" >/dev/null 2>&1; then
  kill "$PID"
  echo "Stopped frontend dev server pid $PID"
else
  echo "Frontend dev server is not running"
fi

rm -f "$PID_FILE"
