#!/usr/bin/env bash
# route-tier.sh — resolve a task description to a tier, model and effort.
#
# aicr owns the routing declaration (ROUTE_*/MODEL_*/EFFORT_* in .ai/config);
# this is its reference resolver, so every consumer routes identically instead
# of reimplementing the match.
#
#   route-tier.sh "migrate the dashboard to React"   -> DEEP opus high
#   route-tier.sh --model "fix the P&L rounding"     -> sonnet
#
# Precedence is DEEP > BALANCED > FAST: a task naming work from two tiers gets
# the more capable one. Under-spending on a hard task costs more than the
# reverse, because the bad plan is paid for again in the fix passes.
#
# Exit 0 = resolved. Exit 3 = no config. Exit 4 = --strict and nothing matched.
# A caller that cannot tolerate a guess uses --strict and keeps its own default
# on 3 or 4: "I could not classify this" must not be reported as "balanced".

set -uo pipefail

CONFIG="${AICR_CONFIG:-${AICR_DIR:-.ai}/config}"
want=both
strict=0

while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    --model)  want=model;  shift ;;
    --tier)   want=tier;   shift ;;
    --effort) want=effort; shift ;;
    --strict) strict=1;    shift ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

[ -f "$CONFIG" ] || exit 3

# shellcheck disable=SC1090
. "$CONFIG"

text=$(printf '%s ' "$@" | tr '[:upper:]' '[:lower:]')

tier="${DEFAULT_TIER:-BALANCED}"
resolved=0
for candidate in DEEP BALANCED FAST; do
  keywords_var="ROUTE_${candidate}"
  keywords="${!keywords_var:-}"
  [ -n "$keywords" ] || continue

  matched=0
  # Word-boundary match so "add" does not fire inside "address".
  while IFS= read -r keyword; do
    keyword=$(printf '%s' "$keyword" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    [ -n "$keyword" ] || continue
    if printf '%s' "$text" | grep -qiE "(^|[^a-z0-9])${keyword}([^a-z0-9]|$)"; then
      matched=1
      break
    fi
  done <<< "$(printf '%s' "$keywords" | tr ',' '\n')"

  if [ "$matched" -eq 1 ]; then tier="$candidate"; resolved=1; break; fi
done

[ "$strict" -eq 1 ] && [ "$resolved" -eq 0 ] && exit 4

model_var="MODEL_${tier}";  model="${!model_var:-}"
effort_var="EFFORT_${tier}"; effort="${!effort_var:-${EFFORT_DEFAULT:-medium}}"

case "$want" in
  model)  printf '%s\n' "$model" ;;
  tier)   printf '%s\n' "$tier" ;;
  effort) printf '%s\n' "$effort" ;;
  both)   printf '%s %s %s\n' "$tier" "$model" "$effort" ;;
esac
