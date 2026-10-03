#!/usr/bin/env bash
# setup.sh — aicr setup
#
#   ./setup.sh --init [DIR]   scaffold .ai/ into a project and wire the hooks
#   ./setup.sh --tools        install token-optimization tooling for Claude Code
#   ./setup.sh --help         this message
#
# Both modes are idempotent. --tools backs up ~/.claude/settings.json before
# every mutation and verifies the file is still valid JSON afterwards.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"

MODE=""
TARGET="."
SKIP_HEADROOM=false
ASSUME_YES=false

PASS=0; FAIL=0; SKIP=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step() { echo -e "\n${BOLD}${CYAN}▶ $1${RESET}"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; PASS=$((PASS+1)); }
skip() { echo -e "  ${YELLOW}↩${RESET} $1"; SKIP=$((SKIP+1)); }
fail() { echo -e "  ${RED}✗${RESET} $1"; FAIL=$((FAIL+1)); }
info() { echo -e "  ${YELLOW}→${RESET} $1"; }

usage() {
  sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Options for --tools:
  --no-headroom   skip Headroom (use if the Python environment is managed)
  --yes           don't prompt before running third-party install scripts

What --tools installs, and how each one activates:

  RTK          CLI output compression      automatic, PreToolUse hook on Bash
  Caveman      output verbosity reduction  /caveman in a session
  cbm          AST knowledge graph         ask the assistant to index a repo
  Headroom     context compression proxy   immediately (headroom unwrap claude)
  context-mode tool output sandboxing      manual /plugin commands, printed at the end

See docs/token-optimization.md for what each one does and what it claims to save.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --init)        MODE=init; [ $# -gt 1 ] && [[ "$2" != --* ]] && { TARGET="$2"; shift; } ;;
    --tools)       MODE=tools ;;
    --no-headroom) SKIP_HEADROOM=true ;;
    --yes|-y)      ASSUME_YES=true ;;
    --help|-h)     usage; exit 0 ;;
    *)             echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

[ -z "$MODE" ] && { usage; exit 0; }

confirm() {
  $ASSUME_YES && return 0
  read -rp "  ? $1 [y/N] " reply </dev/tty || return 1
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ── Mode: --init ──────────────────────────────────────────────────────────────

if [ "$MODE" = init ]; then
  echo -e "${BOLD}aicr — scaffolding .ai/ into ${TARGET}${RESET}"
  echo "────────────────────────────────────────────────────────"

  [ -d "$TARGET" ] || { fail "$TARGET is not a directory"; exit 1; }

  step "Templates"
  if [ -d "$TARGET/.ai" ]; then
    skip ".ai/ already exists — not overwriting. Diff against $REPO/templates/ by hand."
  else
    mkdir -p "$TARGET/.ai"
    cp "$REPO"/templates/*.md "$TARGET/.ai/"
    cp "$REPO"/templates/config "$TARGET/.ai/"
    cp -r "$REPO"/templates/hooks "$TARGET/.ai/"
    cp "$REPO"/templates/CLAUDE.md.template "$TARGET/.ai/CLAUDE.md"
    chmod +x "$TARGET"/.ai/hooks/*.sh
    ok ".ai/ created from templates"
  fi

  step "CLAUDE.md symlink"
  if [ -e "$TARGET/CLAUDE.md" ] || [ -L "$TARGET/CLAUDE.md" ]; then
    skip "CLAUDE.md already at project root"
  else
    ( cd "$TARGET" && ln -s .ai/CLAUDE.md CLAUDE.md )
    ok "CLAUDE.md -> .ai/CLAUDE.md"
  fi

  step "Hook wiring"
  mkdir -p "$TARGET/.claude"
  if [ -f "$TARGET/.claude/settings.json" ] && grep -q "exclude-guard" "$TARGET/.claude/settings.json"; then
    skip "hooks already wired in .claude/settings.json"
  elif [ -f "$TARGET/.claude/settings.json" ]; then
    info "A .claude/settings.json already exists — merge these hooks in by hand:"
    info "see $REPO/docs/hooks.md"
  else
    cat > "$TARGET/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [{ "type": "command", "command": ".ai/hooks/tier-context.sh" }]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write",
        "hooks": [{ "type": "command", "command": ".ai/hooks/exclude-guard.sh" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read",
        "hooks": [{ "type": "command", "command": ".ai/hooks/context-guard.sh" }]
      }
    ]
  }
}
JSON
    ok "hooks wired in .claude/settings.json"
  fi

  command -v jq >/dev/null 2>&1 || info "jq not found — exclude-guard.sh will fail open until you install it"

  echo ""
  echo "────────────────────────────────────────────────────────"
  echo -e "${BOLD}Next:${RESET}"
  echo "  1. Fill in $TARGET/.ai/CLAUDE.md"
  echo "  2. Set the model tiers in $TARGET/.ai/config"
  echo "  3. Trim $TARGET/.ai/exclusions.md and scope.md to this project"
  echo "  4. Check your work: $REPO/validate.sh $TARGET"
  exit 0
fi

# ── Mode: --tools ─────────────────────────────────────────────────────────────

echo -e "${BOLD}aicr — token optimization tooling for Claude Code${RESET}"
echo "────────────────────────────────────────────────────────"

for c in node python3; do
  command -v "$c" >/dev/null 2>&1 || { fail "Required: $c not found."; exit 1; }
done

node_ver=$(node --version | tr -d 'v' | cut -d. -f1)
[ "$node_ver" -lt 18 ] && { fail "Node >=18 required (found $(node --version))"; exit 1; }

py_ver=$(python3 --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
py_major=${py_ver%%.*}; py_minor=${py_ver##*.}
if [ "$py_major" -lt 3 ] || { [ "$py_major" -eq 3 ] && [ "$py_minor" -lt 10 ]; }; then
  fail "Python >=3.10 required (found $py_ver)"; exit 1
fi
info "Node $(node --version)  Python $py_ver"

# Snapshot settings.json so a bad mutation is always recoverable, and so we can
# tell whether a third-party installer clobbered hooks that were already there.
HOOKS_BEFORE=0
backup_settings() {
  [ -f "$SETTINGS" ] || return 0
  cp "$SETTINGS" "${SETTINGS}.bak.$(date +%s)"
  HOOKS_BEFORE=$(grep -c '"type": *"command"' "$SETTINGS" 2>/dev/null || echo 0)
}

# Generic integrity check: valid JSON, and no pre-existing hook silently dropped.
# Deliberately not tied to any specific hook — this runs on other people's machines.
verify_settings() {
  [ -f "$SETTINGS" ] || return 0
  if command -v jq >/dev/null 2>&1 && ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
    fail "settings.json is no longer valid JSON — restore from ${SETTINGS}.bak.*"
    return 1
  fi
  local after
  after=$(grep -c '"type": *"command"' "$SETTINGS" 2>/dev/null || echo 0)
  if [ "$after" -lt "$HOOKS_BEFORE" ]; then
    fail "hook count dropped ($HOOKS_BEFORE -> $after) — restore from ${SETTINGS}.bak.*"
    return 1
  fi
  ok "settings.json intact ($after hooks)"
}

# curl | bash is how these projects ship. Make it a visible decision, not a default.
run_remote_installer() {
  local name="$1" url="$2"
  info "Installer: $url"
  if ! confirm "Run the $name install script?"; then
    skip "$name skipped by user"
    return 1
  fi
  curl -fsSL "$url" | bash
}

step "RTK — CLI output compression"
if command -v rtk >/dev/null 2>&1; then
  info "rtk $(rtk --version 2>/dev/null | head -1) present"
else
  if command -v brew >/dev/null 2>&1; then
    brew install rtk-ai/tap/rtk 2>&1 | grep -E "^(==>|Error)" || true
  else
    fail "RTK installs via Homebrew, which was not found. See docs/token-optimization.md."
  fi
fi
if command -v rtk >/dev/null 2>&1; then
  if [ -f "$SETTINGS" ] && grep -q '"rtk' "$SETTINGS"; then
    skip "RTK hook already in settings.json"
  else
    backup_settings
    if rtk init -g; then ok "RTK hook added"; verify_settings; else fail "rtk init -g failed"; fi
  fi
fi

step "Caveman — output verbosity reduction"
if [ -f "$HOME/.claude/skills/caveman.md" ]; then
  skip "Caveman already installed"
elif run_remote_installer "Caveman" \
      "https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh"; then
  ok "Caveman installed — enable with /caveman in a session"
fi

step "codebase-memory-mcp — AST knowledge graph"
if command -v codebase-memory-mcp >/dev/null 2>&1 || [ -f "$HOME/.local/bin/codebase-memory-mcp" ]; then
  skip "codebase-memory-mcp already installed"
else
  backup_settings
  if run_remote_installer "codebase-memory-mcp" \
      "https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh"; then
    ok "installed — restart Claude Code, then ask it to index a repo"
    verify_settings
  fi
fi

step "Headroom — context compression proxy"
if $SKIP_HEADROOM; then
  skip "Headroom skipped (--no-headroom)"
elif command -v headroom >/dev/null 2>&1; then
  info "headroom already present"
else
  # PEP 668 marks many system Pythons as externally managed; pipx is the clean path.
  if command -v pipx >/dev/null 2>&1; then
    pipx install "headroom-ai[all]" && ok "headroom-ai installed via pipx" || fail "pipx install failed"
  elif pip install "headroom-ai[all]" --quiet 2>/dev/null; then
    ok "headroom-ai installed via pip"
  else
    fail "pip refused (likely PEP 668). Install pipx, or re-run with --no-headroom."
    SKIP_HEADROOM=true
  fi
fi
if ! $SKIP_HEADROOM && command -v headroom >/dev/null 2>&1; then
  if confirm "Wrap the claude binary with headroom? (reverse: headroom unwrap claude)"; then
    headroom wrap claude && ok "Headroom active — monitor with: headroom dashboard"
  else
    skip "headroom wrap declined"
  fi
fi

step "context-mode — tool output sandboxing"
info "Installs through Claude Code's plugin system. Run these in a session:"
echo ""
echo -e "    ${BOLD}/plugin marketplace add mksglu/context-mode${RESET}"
echo -e "    ${BOLD}/plugin install context-mode@context-mode${RESET}"
echo ""
info "Verify with: /context-mode:ctx-doctor"

echo ""
echo "────────────────────────────────────────────────────────"
echo -e "${BOLD}Results: ${GREEN}$PASS done${RESET}  ${YELLOW}$SKIP skipped${RESET}  ${RED}$FAIL failed${RESET}"
[ -f "${SETTINGS}.bak."* ] 2>/dev/null && info "Backups: ${SETTINGS}.bak.*"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
