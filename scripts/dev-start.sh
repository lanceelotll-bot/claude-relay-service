#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT_DIR/pids/dev-app.pid"
LOG_FILE="$ROOT_DIR/logs/dev-app.log"

cd "$ROOT_DIR"

mkdir -p pids logs

if ! bash "$ROOT_DIR/scripts/dev-upstream-check.sh"; then
  echo "[dev-start] upstream check failed unexpectedly, continue startup."
fi

SKIP_WEB_BUILD=1 bash "$ROOT_DIR/scripts/dev-bootstrap.sh"
bash "$ROOT_DIR/scripts/dev-redis-start.sh"

APP_PID=""
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  APP_PID="$(cat "$PID_FILE")"
else
  APP_PID="$(lsof -tiTCP:3000 -sTCP:LISTEN 2>/dev/null | head -n 1 || true)"
fi

if [ -n "$APP_PID" ] && kill -0 "$APP_PID" >/dev/null 2>&1; then
  echo "$APP_PID" >"$PID_FILE"
  echo "CRS app already running on pid $APP_PID"
  exit 0
fi

nohup node src/app.js >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 4

if ! kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  echo "CRS app failed to start. Check $LOG_FILE"
  exit 1
fi

echo "CRS app started on pid $(cat "$PID_FILE")"
echo "Logs: $LOG_FILE"
