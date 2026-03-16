#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REDIS_BIN="$ROOT_DIR/.local/bin/redis-server"
PID_FILE="$ROOT_DIR/pids/dev-redis.pid"
LOG_FILE="$ROOT_DIR/logs/dev-redis.log"
DATA_DIR="$ROOT_DIR/redis_data/dev-local"
PORT="${REDIS_PORT:-6379}"

cd "$ROOT_DIR"

mkdir -p "$(dirname "$PID_FILE")" "$(dirname "$LOG_FILE")" "$DATA_DIR"

if [ ! -x "$REDIS_BIN" ]; then
  bash "$ROOT_DIR/scripts/dev-redis-bootstrap.sh"
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  echo "Redis already running on pid $(cat "$PID_FILE")"
  exit 0
fi

nohup "$REDIS_BIN" \
  --bind 127.0.0.1 \
  --port "$PORT" \
  --dir "$DATA_DIR" \
  --save 60 1 \
  --appendonly yes \
  --appendfilename appendonly.aof \
  >"$LOG_FILE" 2>&1 &

echo $! >"$PID_FILE"
sleep 2

if ! kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  echo "Failed to start Redis. Check $LOG_FILE"
  exit 1
fi

echo "Redis started on 127.0.0.1:$PORT (pid $(cat "$PID_FILE"))"
