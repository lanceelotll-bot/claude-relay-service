#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$ROOT_DIR/.local/cache"
VENDOR_DIR="$ROOT_DIR/.local/vendor"
REDIS_TARBALL="$CACHE_DIR/redis-stable.tar.gz"
REDIS_SRC_DIR="$VENDOR_DIR/redis-stable"
REDIS_BIN="$REDIS_SRC_DIR/src/redis-server"

cd "$ROOT_DIR"

mkdir -p "$CACHE_DIR" "$VENDOR_DIR" .local/run .local/bin

if [ ! -f "$REDIS_TARBALL" ]; then
  echo "Downloading Redis source..."
  curl -L https://download.redis.io/redis-stable.tar.gz -o "$REDIS_TARBALL"
fi

if [ ! -d "$REDIS_SRC_DIR" ]; then
  mkdir -p "$REDIS_SRC_DIR"
  tar -xzf "$REDIS_TARBALL" -C "$REDIS_SRC_DIR" --strip-components=1
fi

if [ ! -x "$REDIS_BIN" ]; then
  echo "Building Redis locally..."
  make -C "$REDIS_SRC_DIR" distclean >/dev/null 2>&1 || true
  make -C "$REDIS_SRC_DIR" MALLOC=libc BUILD_TLS=no -j"$(sysctl -n hw.ncpu)"
fi

ln -sf "$REDIS_BIN" "$ROOT_DIR/.local/bin/redis-server"
ln -sf "$REDIS_SRC_DIR/src/redis-cli" "$ROOT_DIR/.local/bin/redis-cli"

echo "Local Redis ready:"
echo "  $REDIS_BIN"
