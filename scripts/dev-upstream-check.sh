#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

is_enabled() {
  local raw="${1:-}"
  local normalized
  normalized="$(echo "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$normalized" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

if ! is_enabled "${DEV_UPSTREAM_CHECK:-true}"; then
  exit 0
fi

cd "$ROOT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[upstream-check] skipped: current directory is not a Git repository."
  exit 0
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "[upstream-check] skipped: upstream remote is not configured."
  exit 0
fi

BRANCH_TO_CHECK="${BASE_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo develop)}"
if [ "$BRANCH_TO_CHECK" = "HEAD" ] || [ -z "$BRANCH_TO_CHECK" ]; then
  BRANCH_TO_CHECK="develop"
fi

if ! git rev-parse --verify "$BRANCH_TO_CHECK" >/dev/null 2>&1; then
  echo "[upstream-check] skipped: local branch '$BRANCH_TO_CHECK' does not exist."
  exit 0
fi

if ! git rev-parse --verify upstream/main >/dev/null 2>&1; then
  echo "[upstream-check] fetching upstream/main..."
fi

if ! git fetch upstream --prune >/dev/null 2>&1; then
  echo "[upstream-check] warning: failed to fetch upstream. Continue startup."
  exit 0
fi

COUNTS="$(git rev-list --left-right --count "${BRANCH_TO_CHECK}...upstream/main" 2>/dev/null || echo "0 0")"
AHEAD_COUNT="$(echo "$COUNTS" | awk '{print $1}')"
BEHIND_COUNT="$(echo "$COUNTS" | awk '{print $2}')"

if [ "${BEHIND_COUNT:-0}" -gt 0 ]; then
  echo
  echo "[upstream-check] upstream/main is ahead of ${BRANCH_TO_CHECK} by ${BEHIND_COUNT} commit(s)."
  echo "[upstream-check] Recommendation: create a sync branch and review before merging."
  echo "[upstream-check] Command: bash scripts/git-create-sync-branch.sh"
  echo

  if is_enabled "${DEV_UPSTREAM_PROMPT_CREATE:-true}" && [ -t 0 ]; then
    read -r -p "Create sync branch now? [y/N] " ANSWER
    case "${ANSWER:-}" in
      y|Y|yes|YES)
        if bash "$ROOT_DIR/scripts/git-create-sync-branch.sh"; then
          echo "[upstream-check] sync branch created."
        else
          echo "[upstream-check] sync branch creation failed. Continue startup."
        fi
        ;;
      *)
        echo "[upstream-check] skipped creating sync branch."
        ;;
    esac
  fi
else
  echo "[upstream-check] ${BRANCH_TO_CHECK} is up to date with upstream/main (ahead ${AHEAD_COUNT:-0}, behind 0)."
fi

exit 0
