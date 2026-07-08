#!/usr/bin/env bash
# setup.sh — Token optimization tools for Claude Code
# Installs and configures: RTK, Caveman, codebase-memory-mcp, Headroom
# context-mode requires a manual /plugin command (see end of output)
#
# Usage:
#   ./setup.sh              # full install
#   ./setup.sh --no-headroom  # skip Headroom (if Python env issues)
#
# Idempotent: safe to re-run.

set -uo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

SKIP_HEADROOM=false
[[ "${1:-}" == "--no-headroom" ]] && SKIP_HEADROOM=true

SETTINGS="$HOME/.claude/settings.json"
PASS=0; FAIL=0; SKIP=0

# ── Helpers ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

step()  { echo -e "\n${BOLD}${CYAN}▶ $1${RESET}"; }
ok()    { echo -e "  ${GREEN}✓${RESET} $1"; PASS=$((PASS+1)); }
skip()  { echo -e "  ${YELLOW}↩${RESET} $1 (already done)"; SKIP=$((SKIP+1)); }
fail()  { echo -e "  ${RED}✗${RESET} $1"; FAIL=$((FAIL+1)); }
info()  { echo -e "  ${YELLOW}→${RESET} $1"; }

require() {
  if ! command -v "$1" &>/dev/null; then
    fail "Required: $1 not found. Install it and re-run."
    exit 1
  fi
}

# Backup settings.json before any mutation
backup_settings() {
  if [ -f "$SETTINGS" ]; then
    cp "$SETTINGS" "${SETTINGS}.bak.$(date +%s)"
  fi
}

# Check that session-lens Stop hook survived a mutation
assert_sessionlens_intact() {
  if [ -f "$SETTINGS" ] && grep -q "sessionlens-hook" "$SETTINGS"; then
    ok "session-lens Stop hook intact"
  else
    fail "session-lens Stop hook missing from settings.json — check ${SETTINGS}.bak.*"
  fi
}

# ── Prerequisites ─────────────────────────────────────────────────────────────

echo -e "${BOLD}Token Optimization Setup — Claude Code${RESET}"
echo "────────────────────────────────────────────────────────"

require brew
require node
require python3

node_ver=$(node --version | tr -d 'v' | cut -d. -f1)
if [ "$node_ver" -lt 18 ]; then
  fail "Node ≥18 required (found $(node --version)). Run: brew install node"
  exit 1
fi

py_ver=$(python3 --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
py_major=$(echo "$py_ver" | cut -d. -f1)
py_minor=$(echo "$py_ver" | cut -d. -f2)
if [ "$py_major" -lt 3 ] || { [ "$py_major" -eq 3 ] && [ "$py_minor" -lt 10 ]; }; then
  fail "Python ≥3.10 required (found $py_ver)"
  exit 1
fi

info "Node $(node --version) ✓  Python $py_ver ✓  Homebrew ✓"

# ── 1. RTK — CLI output compression ──────────────────────────────────────────

step "RTK — CLI output compression (60-90%)"

if ! command -v rtk &>/dev/null; then
  info "Installing RTK via Homebrew..."
  brew install rtk-ai/tap/rtk 2>&1 | grep -E "^(==>|Error|🍺)" || true
fi

if ! command -v rtk &>/dev/null; then
  fail "RTK install failed"
else
  info "RTK $(rtk --version 2>/dev/null | head -1) installed"

  # Check if PreToolUse hook already present
  if [ -f "$SETTINGS" ] && grep -q '"rtk"' "$SETTINGS"; then
    skip "RTK hook already in settings.json"
  else
    backup_settings
    info "Running: rtk init -g (adds PreToolUse hook to settings.json)"
    if rtk init -g 2>&1 | grep -v "^$"; then
      ok "RTK hook added to settings.json"
      assert_sessionlens_intact
    else
      fail "rtk init -g failed — check output above"
    fi
  fi
fi

# ── 2. Caveman — output verbosity reduction ───────────────────────────────────

step "Caveman — output token reduction (50-75%)"

CAVEMAN_MARKER="$HOME/.claude/skills/caveman.md"
if [ -f "$CAVEMAN_MARKER" ]; then
  skip "Caveman already installed ($CAVEMAN_MARKER)"
else
  info "Installing Caveman..."
  if curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash 2>&1; then
    if [ -f "$CAVEMAN_MARKER" ]; then
      ok "Caveman installed — activate with /caveman in any Claude session"
    else
      # Some installs land in different locations
      ok "Caveman install script ran — verify with /caveman in Claude Code"
    fi
  else
    fail "Caveman install script failed"
  fi
fi

# ── 3. codebase-memory-mcp — knowledge graph ─────────────────────────────────

step "codebase-memory-mcp — AST knowledge graph (99% on structural queries)"

CBM_BIN="$HOME/.local/bin/codebase-memory-mcp"
if command -v codebase-memory-mcp &>/dev/null || [ -f "$CBM_BIN" ]; then
  skip "codebase-memory-mcp already installed"
else
  info "Installing codebase-memory-mcp (tree-sitter, 158 languages)..."
  backup_settings
  if curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash 2>&1; then
    if command -v codebase-memory-mcp &>/dev/null || [ -f "$CBM_BIN" ]; then
      ok "codebase-memory-mcp installed — ask Claude to 'Index this project' in any repo"
      assert_sessionlens_intact
    else
      ok "codebase-memory-mcp install ran — restart Claude Code to activate MCP"
    fi
  else
    fail "codebase-memory-mcp install failed"
  fi
fi

# ── 4. Headroom — context compression proxy ───────────────────────────────────

step "Headroom — context compression (47-92%)"

if $SKIP_HEADROOM; then
  skip "Headroom skipped (--no-headroom flag)"
else
  if command -v headroom &>/dev/null; then
    info "headroom CLI already present"
  else
    info "Installing headroom-ai (Python $py_ver)..."
    if pip install "headroom-ai[all]" --quiet 2>&1 | tail -3; then
      ok "headroom-ai installed"
    else
      fail "pip install headroom-ai[all] failed — try ./setup.sh --no-headroom"
      SKIP_HEADROOM=true
    fi
  fi

  if ! $SKIP_HEADROOM && command -v headroom &>/dev/null; then
    info "Running: headroom wrap claude (reversible via: headroom unwrap claude)"
    if headroom wrap claude 2>&1; then
      ok "Headroom wrapping Claude Code — run 'headroom dashboard' to monitor savings"
    else
      fail "headroom wrap claude failed"
    fi
  fi
fi

# ── 5. context-mode — manual step required ───────────────────────────────────

step "context-mode — tool output sandboxing (98%)"
echo ""
info "context-mode installs via Claude Code's plugin system."
info "Type these two commands inside a Claude Code session:"
echo ""
echo -e "    ${BOLD}/plugin marketplace add mksglu/context-mode${RESET}"
echo -e "    ${BOLD}/plugin install context-mode@context-mode${RESET}"
echo ""
info "Then verify with: /context-mode:ctx-doctor"
info "Optional statusline — add to ~/.claude/settings.json:"
echo '    "statusLine": {"type": "command", "command": "context-mode statusline"}'

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────────────────────"
echo -e "${BOLD}Results: ${GREEN}$PASS done${RESET}  ${YELLOW}$SKIP skipped${RESET}  ${RED}$FAIL failed${RESET}"
echo ""
echo -e "${BOLD}What activates when:${RESET}"
echo "  RTK          — automatic on every Bash tool call (hook installed)"
echo "  Caveman      — type /caveman in any Claude session to enable"
echo "  cbm          — ask Claude to 'Index this project' in a repo"
echo "  Headroom     — active now (wrapping claude binary)"
echo "  context-mode — active after you run the /plugin commands above"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}Some steps failed. Check output above and re-run.${RESET}"
  exit 1
fi
