#!/usr/bin/env bash

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: current directory is not a Git repository."
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree has uncommitted changes. Commit or stash them first."
  exit 1
fi

if [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo "Error: working tree has untracked files. Commit, ignore, or move them first."
  exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Error: upstream remote is not configured."
  exit 1
fi

ORIGINAL_BRANCH="$(git branch --show-current)"

echo "Fetching upstream..."
git fetch upstream --prune

echo "Syncing main with upstream/main..."
if git show-ref --verify --quiet refs/heads/main; then
  git checkout main
else
  git checkout -b main upstream/main
fi

if ! git merge --ff-only upstream/main; then
  git merge --no-edit upstream/main
fi

if git remote get-url origin >/dev/null 2>&1; then
  echo "Pushing main to origin..."
  git push origin main
fi

if git show-ref --verify --quiet refs/heads/develop; then
  echo "Merging main into develop..."
  git checkout develop
  git merge --no-edit main

  if git remote get-url origin >/dev/null 2>&1; then
    echo "Pushing develop to origin..."
    git push origin develop
  fi
fi

if [ "$ORIGINAL_BRANCH" != "$(git branch --show-current)" ] && git show-ref --verify --quiet "refs/heads/$ORIGINAL_BRANCH"; then
  git checkout "$ORIGINAL_BRANCH"
fi

echo "Done. main now tracks upstream changes, and develop includes the latest main merge."
