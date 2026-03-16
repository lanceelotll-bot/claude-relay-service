#!/usr/bin/env bash

set -euo pipefail

SIDECAR_HOST="${SS_SIDECAR_TEST_HOST:-127.0.0.1}"
SIDECAR_PORT="${SS_SIDECAR_SOCKS_PORT:-11080}"
TEST_URL="${1:-https://api.anthropic.com/v1/messages}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for SS proxy test."
  exit 1
fi

START_MS="$(date +%s%3N 2>/dev/null || true)"

set +e
RESULT="$(curl --silent --show-error --output /dev/null \
  --socks5-hostname "${SIDECAR_HOST}:${SIDECAR_PORT}" \
  --max-time 20 \
  --write-out 'http_code=%{http_code} time_total=%{time_total}' \
  "$TEST_URL" 2>&1)"
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ]; then
  echo "SS sidecar test failed: $RESULT"
  exit 1
fi

HTTP_CODE="$(echo "$RESULT" | sed -n 's/.*http_code=\([0-9][0-9][0-9]\).*/\1/p')"
TIME_TOTAL="$(echo "$RESULT" | sed -n 's/.*time_total=\([0-9.]*\).*/\1/p')"
LATENCY_MS="$(awk "BEGIN { printf \"%.0f\", ${TIME_TOTAL:-0} * 1000 }")"

if [ -n "$START_MS" ] && [[ "$START_MS" =~ ^[0-9]+$ ]]; then
  END_MS="$(date +%s%3N 2>/dev/null || true)"
  if [ -n "$END_MS" ] && [[ "$END_MS" =~ ^[0-9]+$ ]]; then
    WALL_MS="$((END_MS - START_MS))"
  else
    WALL_MS="$LATENCY_MS"
  fi
else
  WALL_MS="$LATENCY_MS"
fi

if [ "$HTTP_CODE" = "000" ] || [ -z "$HTTP_CODE" ]; then
  echo "SS sidecar test failed: no upstream response"
  exit 1
fi

echo "SS sidecar reachable."
echo "Target: $TEST_URL"
echo "HTTP code: $HTTP_CODE"
echo "Latency: ${LATENCY_MS}ms (wall ${WALL_MS}ms)"
echo
echo "Note: 401/403 is acceptable for connectivity test."
