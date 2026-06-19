#!/usr/bin/env bash
# validate.sh — aicr spec validator
# Usage: ./validate.sh [project_dir]
# Exit 0 = pass, 1 = failures found

set -euo pipefail

DIR="${1:-.}"
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
  local desc="$1" msg="$2"
  printf "  \033[33m⚠\033[0m %s — %s\n" "$desc" "$msg"
  WARN=$((WARN+1))
}

echo "Validating: $DIR"
echo ""
echo "── Structure ───────────────────────────────────────"

[ -d "$DIR/.ai" ] && r="ok" || r=".ai/ directory missing"
check ".ai/ directory exists" "$r"

for f in exclusions.md tools.md scope.md token-budget.md; do
  [ -f "$DIR/.ai/$f" ] && r="ok" || r="missing"
  check ".ai/$f exists" "$r"
done

if [ -f "$DIR/CLAUDE.md" ] || [ -f "$DIR/.ai/CLAUDE.md" ]; then
  check "CLAUDE.md exists (root or .ai/)" "ok"
else
  check "CLAUDE.md exists (root or .ai/)" "missing in both locations"
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
  grep -qi "model routing\|max files" "$DIR/.ai/token-budget.md" && r="ok" || r="no Model Routing or Max files section"
  check "token-budget.md has routing/limits section" "$r"
fi

echo ""
echo "── CLAUDE.md Quality ───────────────────────────────"

CLAUDE_FILE=""
[ -f "$DIR/CLAUDE.md" ] && CLAUDE_FILE="$DIR/CLAUDE.md"
[ -f "$DIR/.ai/CLAUDE.md" ] && CLAUDE_FILE="$DIR/.ai/CLAUDE.md"

if [ -n "$CLAUDE_FILE" ]; then
  line_count=$(wc -l < "$CLAUDE_FILE" | tr -d ' ')
  if [ "$line_count" -le 150 ]; then
    check "CLAUDE.md under 150 lines ($line_count)" "ok"
  elif [ "$line_count" -le 200 ]; then
    warn "CLAUDE.md line count" "$line_count lines — approaching 200-line truncation limit"
  else
    check "CLAUDE.md under 150 lines ($line_count lines — over limit)" "exceeds 150-line budget"
  fi

  for section in "What This Is\|## What" "Architecture" "Development Commands\|## Dev" "Conventions" "Current Focus"; do
    grep -qi "$section" "$CLAUDE_FILE" && r="ok" || r="missing section"
    check "CLAUDE.md has $section" "$r"
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
fi

echo ""
echo "────────────────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed, $WARN warnings"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
