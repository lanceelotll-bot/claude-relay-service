#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

print_status() {
  local name="$1"
  local port="$2"
  local pid_file="$ROOT_DIR/pids/${name}.pid"
  local pid=""

  if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" >/dev/null 2>&1; then
    pid="$(cat "$pid_file")"
  else
    pid="$(lsof -tiTCP:$port -sTCP:LISTEN 2>/dev/null | head -n 1 || true)"
  fi

  if [ -n "$pid" ]; then
    echo "$name running (pid $pid)"
  else
    echo "$name stopped"
  fi
}

print_status dev-app 3000
print_status dev-ui 3001
print_status dev-redis 6379

echo
echo "Health:"
curl -fsS http://127.0.0.1:3000/health || echo "unreachable"
echo
echo "UI:"
curl -I -fsS http://127.0.0.1:3001/admin/ 2>/dev/null | head -n 1 || echo "frontend unreachable"
