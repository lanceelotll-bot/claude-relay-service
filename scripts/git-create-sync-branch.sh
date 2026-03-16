#!/usr/bin/env bash

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: current directory is not a Git repository."
  exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Error: upstream remote is not configured."
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Error: origin remote is not configured."
  exit 1
fi

ROOT_DIR="$(pwd)"
BASE_BRANCH="${BASE_BRANCH:-develop}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SYNC_BRANCH="codex/upstream-sync-${TIMESTAMP}"
WORKTREE_DIR="$ROOT_DIR/.local/update-worktrees/${TIMESTAMP}"
COMPARE_URL=""

mkdir -p "$ROOT_DIR/.local/update-worktrees"

cleanup() {
  if git worktree list --porcelain | grep -q "worktree $WORKTREE_DIR"; then
    git worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

echo "Fetching origin and upstream..."
git fetch origin --prune
git fetch upstream --prune

echo "Creating isolated worktree for sync branch: $SYNC_BRANCH"
git worktree add -B "$SYNC_BRANCH" "$WORKTREE_DIR" "origin/$BASE_BRANCH" >/dev/null

cd "$WORKTREE_DIR"

echo "Merging upstream/main into $SYNC_BRANCH..."
if ! git merge --no-edit upstream/main; then
  STATUS_OUTPUT="$(git status --short || true)"
  git merge --abort >/dev/null 2>&1 || true
  echo "Merge conflict detected. No branch was pushed."
  if [ -n "$STATUS_OUTPUT" ]; then
    echo "$STATUS_OUTPUT"
  fi
  exit 1
fi

echo "Pushing sync branch to origin..."
git push -u origin "$SYNC_BRANCH" >/dev/null

ORIGIN_URL="$(git remote get-url origin)"
if [[ "$ORIGIN_URL" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  COMPARE_URL="https://github.com/${OWNER}/${REPO}/compare/${BASE_BRANCH}...${SYNC_BRANCH}?expand=1"
fi

echo "SYNC_BRANCH=$SYNC_BRANCH"
if [ -n "$COMPARE_URL" ]; then
  echo "COMPARE_URL=$COMPARE_URL"
fi
echo "Done. Review this branch first, then merge it into $BASE_BRANCH."
