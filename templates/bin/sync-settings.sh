#!/usr/bin/env bash
# sync-settings.sh — write Claude Code settings.json from .ai/config.
#
# config is the single source of truth for model + effort (SPEC §1). Claude
# Code reads them from .claude/settings.json. This script resolves the
# BALANCED tier (the default working tier; FAST and DEEP are reached through
# routing, not through settings.json) and writes it into settings.json,
# preserving every other key — hooks, permissions, env.
#
#   sync-settings.sh                       # update ./.claude/settings.json
#   sync-settings.sh --dir ../some-project # update that project's settings
#   sync-settings.sh --check               # exit 1 if out of sync, print diff
#
# Exit 0 = written (or already in sync). Exit 1 = --check and out of sync.
# Exit 2 = missing config. Exit 3 = jq not installed.

set -uo pipefail

PROJECT_DIR="."
mode=write

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)   PROJECT_DIR="$2"; shift 2 ;;
    --check) mode=check; shift ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 64 ;;
  esac
done

CONFIG="${AICR_CONFIG:-${PROJECT_DIR}/${AICR_DIR:-.ai}/config}"
SETTINGS="${PROJECT_DIR}/.claude/settings.json"

[ -f "$CONFIG" ] || { printf 'no config at %s\n' "$CONFIG" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { printf 'jq is required\n' >&2; exit 3; }

# shellcheck disable=SC1090
. "$CONFIG"

model="${MODEL_BALANCED:-}"
effort="${EFFORT_DEFAULT:-${EFFORT_BALANCED:-medium}}"

if [ -z "$model" ]; then
  printf 'MODEL_BALANCED is empty in %s — set it before syncing\n' "$CONFIG" >&2
  exit 2
fi

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"

merged=$(jq --arg m "$model" --arg e "$effort" \
  '. + {model: $m, effortLevel: $e}' "$SETTINGS")

if [ "$mode" = check ]; then
  if diff -q <(printf '%s\n' "$merged") "$SETTINGS" >/dev/null 2>&1; then
    exit 0
  fi
  printf 'settings.json out of sync with %s\n' "$CONFIG" >&2
  diff -u "$SETTINGS" <(printf '%s\n' "$merged") || true
  exit 1
fi

printf '%s\n' "$merged" > "$SETTINGS"
printf 'wrote model=%s effortLevel=%s to %s\n' "$model" "$effort" "$SETTINGS"
