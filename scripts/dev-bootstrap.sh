#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/config.js"
ENV_FILE="$ROOT_DIR/.env"
SKIP_WEB_BUILD="${SKIP_WEB_BUILD:-0}"

cd "$ROOT_DIR"

mkdir -p logs data temp pids .local/cache .local/vendor .local/run .local/bin

if [ ! -d "$ROOT_DIR/node_modules" ]; then
  echo "Installing root dependencies..."
  npm install
fi

if [ ! -f "$CONFIG_FILE" ]; then
  cp "$ROOT_DIR/config/config.example.js" "$CONFIG_FILE"
  echo "Created config/config.js from config/config.example.js"
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Generating .env and admin credentials via npm run setup..."
  npm run setup
else
  echo ".env already exists, skipping setup-generated env creation"
  if [ ! -f "$ROOT_DIR/data/init.json" ]; then
    echo "Generating admin credentials via npm run setup..."
    npm run setup
  fi
fi

if [ "$SKIP_WEB_BUILD" = "1" ]; then
  echo "Skipping frontend install/build for backend-only startup"
  echo "Bootstrap complete."
  exit 0
fi

if [ ! -d "$ROOT_DIR/web/admin-spa/node_modules" ]; then
  echo "Installing frontend dependencies..."
  npm run install:web
fi

echo "Building frontend admin app..."
npm run build:web

echo "Bootstrap complete."
