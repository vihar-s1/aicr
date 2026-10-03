#!/usr/bin/env bash
# tier-context.sh — inject the routing policy at session start.
#
# Claude Code SessionStart hook. Reads .ai/config and returns the tier
# table as additionalContext, so the assistant starts the session knowing
# which model and effort level each kind of work belongs to.
#
# Without this, token-budget.md is advice nobody read. With it, the policy
# is in context from turn one.
#
# Always exits 0 — a missing or malformed config must not block a session.

set -uo pipefail

AI_DIR="${AICR_DIR:-.ai}"
CONFIG="$AI_DIR/config"

# Consume stdin so the caller never blocks on an unread pipe.
cat >/dev/null 2>&1 || true

[ -f "$CONFIG" ] || { printf '{}'; exit 0; }

MODEL_FAST=""; MODEL_BALANCED=""; MODEL_DEEP=""
EFFORT_FAST=""; EFFORT_BALANCED=""; EFFORT_DEEP=""
ROUTE_FAST=""; ROUTE_BALANCED=""; ROUTE_DEEP=""
# shellcheck disable=SC1090
source "$CONFIG" 2>/dev/null || { printf '{}'; exit 0; }

# A tier with no model is not actionable — skip it rather than advertise
# a tier the assistant cannot switch to.
row() {
  local tier="$1" model="$2" effort="$3" routes="$4"
  [ -n "$model" ] || return 0
  printf '  %-9s model=%-24s effort=%-7s %s\n' \
    "$tier" "$model" "${effort:-unset}" "${routes:+← $routes}"
}

body=$(
  echo "Model routing policy for this project, from .ai/config."
  echo "Match the task to a tier, then work at that tier's model and effort."
  echo
  row "FAST"     "$MODEL_FAST"     "$EFFORT_FAST"     "$ROUTE_FAST"
  row "BALANCED" "$MODEL_BALANCED" "$EFFORT_BALANCED" "$ROUTE_BALANCED"
  row "DEEP"     "$MODEL_DEEP"     "$EFFORT_DEEP"     "$ROUTE_DEEP"
  echo
  echo "Switch with /model and /effort. Default effort is ${EFFORT_DEFAULT:-medium}."
  echo "Announce a tier change when you make one, so the choice stays visible."
)

# No tier had a model configured — say nothing rather than emit an empty table.
if ! printf '%s' "$body" | grep -q 'model='; then
  printf '{}'
  exit 0
fi

# Encode as a JSON string without assuming jq is installed: this hook must
# work on a bare machine, unlike exclude-guard which genuinely needs a parser.
json_escape() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' \
    | awk 'BEGIN{ORS=""} {print sep $0; sep="\\n"}'
}

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' \
  "$(json_escape "$body")"
exit 0
