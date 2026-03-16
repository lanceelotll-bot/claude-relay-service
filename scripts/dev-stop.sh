#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT_DIR/pids/dev-app.pid"

stop_by_pid_or_port() {
  local label="$1"
  local pid_file="$2"
  local port="$3"
  local pid=""

  if [ -f "$pid_file" ]; then
    pid="$(cat "$pid_file")"
  else
    pid="$(lsof -tiTCP:$port -sTCP:LISTEN 2>/dev/null | head -n 1 || true)"
  fi

  if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid"
    echo "Stopped $label pid $pid"
  else
    echo "$label is not running"
  fi

  rm -f "$pid_file"
}

stop_by_pid_or_port "CRS app" "$PID_FILE" 3000

bash "$ROOT_DIR/scripts/dev-ui-stop.sh"
bash "$ROOT_DIR/scripts/dev-redis-stop.sh"
