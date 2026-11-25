#!/usr/bin/env bash
# validate.sh — aicr spec validator
# Usage: ./validate.sh [project_dir]
# Exit 0 = pass, 1 = failures found

set -uo pipefail

MODE=validate
DIR="."
for arg in "$@"; do
  case "$arg" in
    --measure)  MODE=measure ;;
    --help|-h)  MODE=help ;;
    -*)         echo "Unknown option: $arg" >&2; exit 1 ;;
    *)          DIR="$arg" ;;
  esac
done

PASS=0
FAIL=0
WARN=0

check() {
  local desc="$1" result="$2"
  if [ "$result" = "ok" ]; then
    printf "  \033[32m✓\033[0m %s\n" "$desc"
    PASS=$((PASS+1))
  else
    printf "  \033[31m✗\033[0m %s — %s\n" "$desc" "$result"
    FAIL=$((FAIL+1))
  fi
}

warn() {
  printf "  \033[33m⚠\033[0m %s — %s\n" "$1" "$2"
  WARN=$((WARN+1))
}

if [ "$MODE" = help ]; then
  cat <<'USAGE'
validate.sh — aicr spec validator

  ./validate.sh [DIR]              check DIR against the spec (default: .)
  ./validate.sh --measure [DIR]    report the token cost of always-loaded files
  ./validate.sh --help             this message

Exit 0 = pass, 1 = failures found.
USAGE
  exit 0
fi

# ── Measure ─────────────────────────────────────────────────────────────────
# What gets re-sent every turn is the only cost that compounds. Everything
# else in .ai/ is read on demand and priced once.
if [ "$MODE" = measure ]; then
  AGENT_MD_MAX_LINES=150
  TURNS_PER_SESSION=40
  [ -f "$DIR/.ai/config" ] && { . "$DIR/.ai/config"; } 2>/dev/null

  # ~3.7 chars/token is a reasonable mean for prose-and-code English. This is
  # an estimate, not a tokenizer — it is labelled as one in the output.
  est_tokens() { awk -v c="$1" 'BEGIN { printf "%d", (c / 3.7) + 0.5 }'; }
  commas() { awk -v n="$1" 'BEGIN{
    s=sprintf("%d", n); out=""; len=length(s)
    for (i = 1; i <= len; i++) {
      out = out substr(s, i, 1)
      r = len - i
      if (r > 0 && r % 3 == 0) out = out ","
    }
    print out }'; }

  echo "Measuring: $DIR"
  echo ""
  echo "── Loaded every turn ───────────────────────────────"

  CLAUDE_FILE=""
  [ -f "$DIR/CLAUDE.md" ] && CLAUDE_FILE="$DIR/CLAUDE.md"
  [ -f "$DIR/.ai/CLAUDE.md" ] && CLAUDE_FILE="$DIR/.ai/CLAUDE.md"

  turn_tokens=0
  if [ -n "$CLAUDE_FILE" ]; then
    chars=$(wc -c < "$CLAUDE_FILE" | tr -d ' ')
    lines=$(wc -l < "$CLAUDE_FILE" | tr -d ' ')
    turn_tokens=$(est_tokens "$chars")
    printf "  %-34s %6s lines  ~%7s tokens\n" \
      "${CLAUDE_FILE#"$DIR"/}" "$lines" "$(commas "$turn_tokens")"
  else
    printf "  (no CLAUDE.md found)\n"
  fi

  echo ""
  echo "── Loaded on demand ────────────────────────────────"
  ondemand=0
  for f in config exclusions.md scope.md tools.md token-budget.md; do
    [ -f "$DIR/.ai/$f" ] || continue
    chars=$(wc -c < "$DIR/.ai/$f" | tr -d ' ')
    t=$(est_tokens "$chars")
    ondemand=$((ondemand + t))
    printf "  %-34s %6s lines  ~%7s tokens\n" \
      ".ai/$f" "$(wc -l < "$DIR/.ai/$f" | tr -d ' ')" "$(commas "$t")"
  done
  printf "  %-34s %6s        ~%7s tokens\n" "(subtotal)" "" "$(commas "$ondemand")"

  echo ""
  echo "── Projected ───────────────────────────────────────"
  session=$((turn_tokens * TURNS_PER_SESSION))
  printf "  Per turn                           ~%9s tokens\n" "$(commas "$turn_tokens")"
  printf "  Per session (%s turns)              ~%9s tokens\n" \
    "$TURNS_PER_SESSION" "$(commas "$session")"

  echo ""
  if [ "$turn_tokens" -gt 4000 ]; then
    printf "  \033[31m✗\033[0m CLAUDE.md is heavy — every turn pays this. Cut it.\n"
  elif [ "$turn_tokens" -gt 2000 ]; then
    printf "  \033[33m⚠\033[0m CLAUDE.md is getting expensive. Audit it for unused context.\n"
  elif [ -n "$CLAUDE_FILE" ]; then
    printf "  \033[32m✓\033[0m CLAUDE.md is lean.\n"
  fi

  echo ""
  echo "────────────────────────────────────────────────────"
  echo "Estimated at ~3.7 chars/token. For an exact count, use the"
  echo "Anthropic API's count_tokens endpoint — tiktoken is OpenAI's"
  echo "tokenizer and will not match Claude."
  exit 0
fi

echo "Validating: $DIR"
echo ""

# aicr-style repo convention: templates/ + self/ at root means .ai/ is a
# build artifact. Auto-bootstrap if it's missing so a fresh clone validates
# with one command.
if [ -d "$DIR/templates" ] && [ ! -d "$DIR/.ai" ] && [ -x "$DIR/setup.sh" ]; then
  echo "── Bootstrap ───────────────────────────────────────"
  "$DIR/setup.sh" --self "$DIR" >/dev/null 2>&1 \
    && printf "  \033[32m✓\033[0m .ai/ composed from templates/%s\n" \
      "$([ -d "$DIR/self" ] && echo " + self/")" \
    || printf "  \033[31m✗\033[0m setup.sh --self failed — run it manually to see why\n"
  echo ""
fi

echo "── Structure ───────────────────────────────────────"

[ -d "$DIR/.ai" ] && r="ok" || r=".ai/ directory missing"
check ".ai/ directory exists" "$r"

for f in config exclusions.md tools.md scope.md token-budget.md; do
  [ -f "$DIR/.ai/$f" ] && r="ok" || r="missing"
  check ".ai/$f exists" "$r"
done

if [ -f "$DIR/CLAUDE.md" ] || [ -f "$DIR/.ai/CLAUDE.md" ]; then
  check "CLAUDE.md exists (root or .ai/)" "ok"
else
  check "CLAUDE.md exists (root or .ai/)" "missing in both locations"
fi

echo ""
echo "── Config ──────────────────────────────────────────"

AGENT_MD_MAX_LINES=150
CONFIG="$DIR/.ai/config"
if [ -f "$CONFIG" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG"

  for key in MAX_FILES WARN_FILES MAX_FILE_LINES AGENT_MD_MAX_LINES; do
    if [ -n "${!key:-}" ]; then
      check "config defines $key (${!key})" "ok"
    else
      check "config defines $key" "unset"
    fi
  done

  if [ -n "${MAX_FILES:-}" ] && [ -n "${WARN_FILES:-}" ] && [ "$WARN_FILES" -ge "$MAX_FILES" ]; then
    check "WARN_FILES below MAX_FILES" "WARN_FILES ($WARN_FILES) >= MAX_FILES ($MAX_FILES)"
  else
    check "WARN_FILES below MAX_FILES" "ok"
  fi

  tiers_set=0
  for key in MODEL_FAST MODEL_BALANCED MODEL_DEEP; do
    [ -n "${!key:-}" ] && tiers_set=$((tiers_set+1))
  done
  if [ "$tiers_set" -eq 0 ]; then
    warn "model tiers" "MODEL_FAST/BALANCED/DEEP all empty — routing table has nothing to resolve to"
  else
    check "model tiers populated ($tiers_set/3)" "ok"
  fi

  bad_effort=""
  for key in EFFORT_FAST EFFORT_BALANCED EFFORT_DEEP EFFORT_DEFAULT; do
    case "${!key:-}" in
      low|medium|high|xhigh) ;;
      "") bad_effort="$bad_effort $key(unset)" ;;
      *)  bad_effort="$bad_effort $key='${!key}'" ;;
    esac
  done
  if [ -z "$bad_effort" ]; then
    check "effort levels valid (low|medium|high|xhigh)" "ok"
  else
    check "effort levels valid" "bad:$bad_effort"
  fi

  routed=0
  for key in ROUTE_FAST ROUTE_BALANCED ROUTE_DEEP; do
    [ -n "${!key:-}" ] && routed=$((routed+1))
  done
  if [ "$routed" -eq 3 ]; then
    check "routing policy defined for all three tiers" "ok"
  elif [ "$routed" -eq 0 ]; then
    warn "routing policy" "no ROUTE_* keywords — tier selection stays manual"
  else
    check "routing policy defined for all three tiers" "only $routed/3 populated"
  fi

  # The config promises these lists are disjoint; a keyword in two tiers makes
  # routing ambiguous, so make good on that promise rather than just asserting it.
  if [ "$routed" -gt 1 ]; then
    dupes=$(
      for key in ROUTE_FAST ROUTE_BALANCED ROUTE_DEEP; do
        printf '%s\n' "${!key:-}" | tr ',' '\n'
      done | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' \
        | sort | uniq -d | paste -sd' ' -
    )
    if [ -n "$dupes" ]; then
      check "routing keywords disjoint across tiers" "appears in >1 tier: $dupes"
    else
      check "routing keywords disjoint across tiers" "ok"
    fi
  fi

  if [ -n "${TURNS_PER_SESSION:-}" ]; then
    check "config defines TURNS_PER_SESSION (${TURNS_PER_SESSION})" "ok"
  else
    warn "TURNS_PER_SESSION" "unset — --measure will assume 40"
  fi
fi

echo ""
echo "── Content ─────────────────────────────────────────"

if [ -f "$DIR/.ai/exclusions.md" ]; then
  count=$(grep -v '^#' "$DIR/.ai/exclusions.md" | grep -v '^$' | wc -l | tr -d ' ')
  [ "$count" -gt 0 ] && r="ok" || r="no patterns defined"
  check "exclusions.md has at least one pattern" "$r"
fi

if [ -f "$DIR/.ai/tools.md" ]; then
  grep -qi "tool permissions" "$DIR/.ai/tools.md" && r="ok" || r="no '## Tool Permissions' section"
  check "tools.md has Tool Permissions section" "$r"
fi

if [ -f "$DIR/.ai/scope.md" ]; then
  grep -qi "in-scope\|in scope" "$DIR/.ai/scope.md" && r="ok" || r="no '## In-Scope' section"
  check "scope.md has In-Scope section" "$r"
fi

if [ -f "$DIR/.ai/token-budget.md" ]; then
  grep -qi "model routing\|effort" "$DIR/.ai/token-budget.md" && r="ok" || r="no Model Routing or Effort section"
  check "token-budget.md has routing/effort section" "$r"

  # Model IDs belong in config, not scattered through prose.
  if grep -qiE 'claude-[a-z]+-[0-9]|gpt-[0-9]|gemini-[0-9]' "$DIR/.ai/token-budget.md"; then
    warn "token-budget.md hardcodes model IDs" "use MODEL_FAST/BALANCED/DEEP from .ai/config instead"
  else
    check "token-budget.md free of hardcoded model IDs" "ok"
  fi
fi

echo ""
echo "── Enforcement ─────────────────────────────────────"

if [ -d "$DIR/.ai/hooks" ]; then
  for h in exclude-guard.sh context-guard.sh tier-context.sh; do
    if [ ! -f "$DIR/.ai/hooks/$h" ]; then
      warn "hooks/$h" "not installed — the matching .ai/ file is advisory only"
    elif [ ! -x "$DIR/.ai/hooks/$h" ]; then
      check "hooks/$h is executable" "not executable — run chmod +x"
    else
      check "hooks/$h installed and executable" "ok"
    fi
  done

  if [ -f "$DIR/.ai/hooks/exclude-guard.sh" ]; then
    if command -v jq >/dev/null 2>&1; then
      check "jq available (exclude-guard dependency)" "ok"
    else
      warn "jq not found" "exclude-guard.sh will fail open and NOT enforce exclusions"
    fi
  fi

  if [ -f "$DIR/.claude/settings.json" ]; then
    for h in exclude-guard tier-context; do
      grep -q "$h" "$DIR/.claude/settings.json" && r="ok" || r="not wired in .claude/settings.json"
      check "$h wired as a hook" "$r"
    done
  else
    warn "hook wiring" "no .claude/settings.json — hooks are present but never invoked"
  fi
else
  warn "hooks/" "no .ai/hooks/ — exclusions.md and context limits are advisory only"
fi

echo ""
echo "── CLAUDE.md Quality ───────────────────────────────"

CLAUDE_FILE=""
[ -f "$DIR/CLAUDE.md" ] && CLAUDE_FILE="$DIR/CLAUDE.md"
[ -f "$DIR/.ai/CLAUDE.md" ] && CLAUDE_FILE="$DIR/.ai/CLAUDE.md"

if [ -n "$CLAUDE_FILE" ]; then
  limit="${AGENT_MD_MAX_LINES:-150}"
  line_count=$(wc -l < "$CLAUDE_FILE" | tr -d ' ')
  if [ "$line_count" -le "$limit" ]; then
    check "CLAUDE.md within $limit lines ($line_count)" "ok"
  else
    check "CLAUDE.md within $limit lines" "$line_count lines — over budget"
  fi

  for section in "What This Is\|## What" "Architecture" "Development Commands\|## Dev" "Conventions" "Current Focus"; do
    grep -qi "$section" "$CLAUDE_FILE" && r="ok" || r="missing section"
    check "CLAUDE.md has ${section%%\\|*}" "$r"
  done

  # Per-H2-section cap: a single bloated section squeezes the required ones
  # and is the usual shape of growth before the hard cap fires.
  section_cap="${AGENT_MD_SECTION_MAX_LINES:-40}"
  over_sections=$(awk -v cap="$section_cap" '
    /^## / { if (name && count > cap) printf "%s|%d\n", name, count; name=$0; count=0; next }
    { count++ }
    END { if (name && count > cap) printf "%s|%d\n", name, count }
  ' "$CLAUDE_FILE")
  if [ -z "$over_sections" ]; then
    check "CLAUDE.md sections within $section_cap lines each" "ok"
  else
    while IFS= read -r over; do
      [ -z "$over" ] && continue
      name="${over%%|*}"; count="${over##*|}"
      check "section '${name#\#\# }' within $section_cap lines" "$count lines — split or trim"
    done <<< "$over_sections"
  fi

  if grep -q "<.*>" "$CLAUDE_FILE" && grep -qi "your-choice\|<cmd>\|<rule>\|<Project Name>" "$CLAUDE_FILE"; then
    warn "CLAUDE.md placeholders" "template placeholders still present — fill them in"
  fi
fi

echo ""
echo "── Overlay Drift ───────────────────────────────────"
# For an aicr-style repo (has templates/ + self/), every file under self/
# must expose a superset of the schema its templates/ counterpart defines.
# Catches the case where a template adds a new config key or markdown
# section and the self/ overlay silently falls behind, producing a .ai/
# that validates today but breaks downstream consumers of the template.
if [ -d "$DIR/templates" ] && [ -d "$DIR/self" ]; then
  for src in "$DIR"/self/*; do
    [ -f "$src" ] || continue
    name="$(basename "$src")"
    tmpl="$DIR/templates/$name"
    [ -f "$tmpl" ] || continue

    case "$name" in
      config)
        missing=$(comm -23 \
          <(grep -oE '^[A-Z_][A-Z0-9_]*=' "$tmpl" | sort -u) \
          <(grep -oE '^[A-Z_][A-Z0-9_]*=' "$src"  | sort -u))
        if [ -z "$missing" ]; then
          check "self/$name covers all keys in templates/$name" "ok"
        else
          check "self/$name covers all keys in templates/$name" \
            "missing: $(echo "$missing" | tr '\n' ' ' | sed 's/=//g; s/ *$//')"
        fi
        ;;
      *.md)
        missing=$(comm -23 \
          <(grep -E '^## ' "$tmpl" | sort -u) \
          <(grep -E '^## ' "$src"  | sort -u))
        if [ -z "$missing" ]; then
          check "self/$name covers all H2 sections in templates/$name" "ok"
        else
          check "self/$name covers all H2 sections in templates/$name" \
            "missing: $(echo "$missing" | tr '\n' '|' | sed 's/## //g; s/|$//')"
        fi
        ;;
    esac
  done
fi

echo ""
echo "── Safety ──────────────────────────────────────────"

if [ -f "$DIR/.env" ]; then
  grep -q "\.env" "$DIR/.gitignore" 2>/dev/null && r="ok" || r=".env is not in .gitignore"
  check ".env is gitignored" "$r"
fi

if [ -f "$DIR/.gitignore" ]; then
  for secret in "*.pem" "*.key" "secrets/"; do
    grep -qF "$secret" "$DIR/.gitignore" 2>/dev/null && r="ok" || r="$secret not in .gitignore"
    check ".gitignore covers $secret" "$r"
  done
else
  check ".gitignore exists" "missing"
fi

echo ""
echo "────────────────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed, $WARN warnings"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
