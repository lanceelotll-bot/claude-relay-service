#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT_DIR/pids/dev-ui.pid"
LOG_FILE="$ROOT_DIR/logs/dev-ui.log"

cd "$ROOT_DIR"

mkdir -p pids logs

if [ ! -d "$ROOT_DIR/web/admin-spa/node_modules" ]; then
  echo "Installing frontend dependencies..."
  npm run install:web
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  echo "Frontend dev server already running on pid $(cat "$PID_FILE")"
  exit 0
fi

nohup env VITE_OPEN_BROWSER=false npm --prefix web/admin-spa run dev -- --host 127.0.0.1 --port 3001 --strictPort >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 4

if ! kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  echo "Frontend dev server failed to start. Check $LOG_FILE"
  exit 1
fi

echo "Frontend dev server started on http://127.0.0.1:3001/admin/ (pid $(cat "$PID_FILE"))"
