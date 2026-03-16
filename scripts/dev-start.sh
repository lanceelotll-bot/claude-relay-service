#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT_DIR/pids/dev-app.pid"
LOG_FILE="$ROOT_DIR/logs/dev-app.log"

cd "$ROOT_DIR"

mkdir -p pids logs

SKIP_WEB_BUILD=1 bash "$ROOT_DIR/scripts/dev-bootstrap.sh"
bash "$ROOT_DIR/scripts/dev-redis-start.sh"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  echo "CRS app already running on pid $(cat "$PID_FILE")"
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
