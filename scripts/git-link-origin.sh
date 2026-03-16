#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${1:-}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: current directory is not a Git repository."
  exit 1
fi

if [ -z "$REPO_URL" ]; then
  cat <<'EOF'
Usage:
  bash scripts/git-link-origin.sh https://github.com/<your-account>/claude-relay-service.git

What this does:
  1. Adds or updates the origin remote
  2. Keeps upstream pointing to the original CRS repository
  3. Prints the next push commands you should run once your GitHub fork exists
EOF
  exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REPO_URL"
  echo "Updated origin -> $REPO_URL"
else
  git remote add origin "$REPO_URL"
  echo "Added origin -> $REPO_URL"
fi

if git remote get-url upstream >/dev/null 2>&1; then
  echo "Upstream stays -> $(git remote get-url upstream)"
else
  echo "Warning: upstream is not configured yet."
fi

cat <<'EOF'

Next steps:
  git push -u origin main
  git push -u origin develop

After that, your GitHub fork becomes the source of truth for:
  - your custom code
  - cross-machine sync
  - deployment from any new machine
EOF
