#!/usr/bin/env bash
# context-guard.sh — warn when a session reads more files than budgeted.
#
# Claude Code PostToolUse hook for Read. Counts reads per session and warns
# at WARN_FILES, then again at MAX_FILES. Limits come from .ai/config, so
# there is one place to change them.
#
# Never blocks: always exits 0. It is a nudge to /compact, not a gate.

set -uo pipefail

AI_DIR="${AICR_DIR:-.ai}"
CONFIG="$AI_DIR/config"

[ -f "$CONFIG" ] || exit 0

# shellcheck disable=SC1090
WARN_FILES=15
MAX_FILES=25
source "$CONFIG"

payload=$(cat)

# Count per session, not globally — parallel sessions must not share a tally.
if command -v jq >/dev/null 2>&1; then
  session=$(printf '%s' "$payload" | jq -r '.session_id // "default"')
else
  session="default"
fi

state="${TMPDIR:-/tmp}/aicr-reads-${session}"
count=$(cat "$state" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "$state"

if [ "$count" -eq "$MAX_FILES" ]; then
  echo "[aicr] $count files read this session — budget is $MAX_FILES. Run /compact." >&2
elif [ "$count" -eq "$WARN_FILES" ]; then
  echo "[aicr] $count files read this session (budget: $MAX_FILES)." >&2
fi

exit 0
