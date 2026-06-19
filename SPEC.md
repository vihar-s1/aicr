# aicr Specification — v0.2

**Date:** 2026-06-19

---

## What This Is

A standard for structuring AI assistant configuration in software projects. The `.ai/` folder works for Claude, Cursor, Copilot, DeepSeek, and whatever comes next. Tool-specific files live inside it; the folder itself is neutral.

**Core goals (equally weighted):**
1. **Config sharing** — commit it, review it, onboard from it
2. **Token control** — prevent waste: wrong model, bloated context, unnecessary reads

---

## Directory Layout

```
<project_root>/
└── .ai/
    ├── CLAUDE.md          # Project context + conventions (Claude reads this every turn)
    ├── exclusions.md      # What the AI must never read
    ├── tools.md           # Allowed/denied tools + output format standards
    ├── scope.md           # Which dirs/files are in scope
    └── token-budget.md    # Model routing, effort levels, context limits
```

**CLAUDE.md location rule:** Claude reads `CLAUDE.md` from the project root or `.claude/` directory. The `.ai/CLAUDE.md` is the source of truth — symlink it to the root.

```bash
ln -s .ai/CLAUDE.md CLAUDE.md
```

---

## 1. File/Folder Exclusions (`exclusions.md`)

Patterns the AI must not read, reference, or include in context. Hard boundary, not a soft suggestion.

**Format:**
```
# Secrets
**/.env*
**/secrets/**
**/*.pem
**/*.key
**/*.p12

# Generated / binary
**/node_modules/**
**/.next/**
**/dist/**
**/build/**
**/__pycache__/**
**/*.lock       # lockfiles bloat context with zero value

# Assets (no value in AI context)
**/public/**
**/*.svg
**/*.png
**/*.jpg
**/*.woff*

# Internal docs not for AI context
**/internal-notes/**
**/threat-model/**
```

**Enforcement:** Wire a `PreToolUse` hook in `.claude/settings.json` to block reads that match exclusion patterns. See [plugins/README.md](plugins/README.md) for `claude-ignore` hook setup.

---

## 2. Token Budget (`token-budget.md`)

Controls context consumption and model selection per task type. **This is the highest-leverage file in the spec.**

### Model Routing Table

The biggest token (and cost) lever is using the right model for the task.

| Task Type | Model | Why |
|---|---|---|
| Search, grep, explore, lookup | Haiku | No reasoning needed; fast + cheap |
| Bug fixes, regular coding, edits | Sonnet | Good balance; default |
| Architecture, code review, complex debug | Opus | Worth the cost; saves iteration |
| Asking questions about code | Haiku | Explanation doesn't need heavy reasoning |

**Rule:** Switch with `/model` mid-session. Never default to Opus for everything.

### Effort Level Mapping

| Task | Effort | Why |
|---|---|---|
| Grep, lookup, one-liner | `low` | No elaboration needed |
| Standard feature, bug fix | `medium` | Default; good output/token ratio |
| Review, architecture, complex refactor | `high` | Fewer iterations worth the extra tokens |
| Security review, multi-file redesign | `max` | Only for decisions you won't revisit |

**Rule:** Default effort is `medium`. Use `high` when the task is complex enough that getting it right the first time saves 3+ follow-up turns.

### Context Limits

```markdown
## Token Budget

**Max files per context window:** 25
**Warn threshold:** 15 files
**Max file size:** 400 lines (summarize or narrow scope beyond this)

## Context Strategy
- Read specific functions, not whole files
- Ask before reading more than 5 files at once
- Files over 400 lines: read relevant section only, not the full file
- Compact with /compact before switching major task contexts
- Compact proactively — don't wait for the limit

## Compaction Triggers
- Switching from debugging to a new feature
- After a completed PR/review cycle
- Before starting a refactor on a different subsystem
```

---

## 3. Tool Permissions (`tools.md`)

Allow/deny list for AI tool use, plus output format standards for common task types.

**Format:**
```markdown
## Tool Permissions

| Tool        | Permission | Notes                                      |
|-------------|------------|--------------------------------------------|
| file_read   | allow      | Within scope.md boundaries only            |
| file_write  | allow      | Confirm before writing new files           |
| bash        | allow      | No destructive commands without approval   |
| web_fetch   | deny       |                                            |
| browser     | deny       |                                            |

## Denied Commands (even if bash is allowed)
- `rm -rf`
- `git push --force`
- `DROP TABLE` or any destructive DB ops without confirmation
- Package installs without approval

## Standardized Tools
- Package manager: <your-choice>
- Test runner: <your-choice>

## Output Format Standards

**Bug fixes:**
- State root cause first
- Show fix as a diff
- No preamble

**Refactoring:**
- Show before/after diff
- One-line note on what changed and why
- Do not touch unrelated code

**New features:**
- Full file for new files, diff for edits
- Create or update tests if test files exist nearby
- Update docs if docs/ file exists for the area

**Code review:**
- List by severity: critical → warning → suggestion
- Format: `file:line — issue — fix`
```

---

## 4. Scope Pinning (`scope.md`)

Defines what's in-scope without explicit override. Out-of-scope dirs should not be read or modified.

**Format:**
```markdown
## In-Scope
- `src/`
- `tests/`
- `docs/`
- `scripts/`

## Out-of-Scope (read-only, never modify)
- `infra/`         # managed by platform team
- `migrations/`    # only touch with explicit instruction
- `.github/`       # CI config, only if asked

## Off-Limits (never read or modify)
- `secrets/`
- `certs/`
- `**/vendor/**`
```

---

## 5. CLAUDE.md Conventions

The most critical file. Claude reads it at the start of every session and every turn. Every byte costs tokens, every session.

### Required Sections

```markdown
# Project Name

## What This Is
One paragraph. What it does, language/framework, who uses it.

## Architecture
3-6 bullet points. Key components, how they connect. No fluff.

## Development Commands
Commands a developer (or AI) needs daily:
- Install: `<cmd>`
- Dev server: `<cmd>`
- Tests: `<cmd>`
- Lint: `<cmd>`
- Build: `<cmd>`

## Conventions
- Naming: <rule>
- File structure: <rule>
- Imports: <rule>

## What NOT To Do
Explicit anti-patterns for this project:
- <pattern to avoid>

## Current Focus
What the active work is. **Update this as work shifts.**
```

### CLAUDE.md Writing Rules

1. **Hard limit: 150 lines.** Claude context is prepended every turn — dense CLAUDE.md is the most expensive repeated cost. Beyond 150 lines you're burning tokens on context that isn't referenced.
2. **Commands over descriptions.** `` `pnpm test` `` is more useful than "we use vitest."
3. **Explicit > implicit.** "Never use `npm install`" not "we prefer pnpm."
4. **No walls of text.** Bullet points, not paragraphs.
5. **Keep `Current Focus` fresh.** Stale focus sections drive the AI to work on the wrong thing.
6. **Audit it quarterly.** Remove anything the AI hasn't needed in the last month.

### What Goes Where

| Content | Location |
|---|---|
| Project description, architecture | `.ai/CLAUDE.md` |
| Dev commands, conventions | `.ai/CLAUDE.md` |
| Anti-patterns, current focus | `.ai/CLAUDE.md` |
| File/folder exclusion patterns | `.ai/exclusions.md` |
| Token budget, model routing | `.ai/token-budget.md` |
| Tool permissions | `.ai/tools.md` |
| Scope boundaries | `.ai/scope.md` |

CLAUDE.md is for project understanding. `.ai/` files are behavioral constraints. Keep them separate.

---

## 6. Claude Code Settings (`settings.json`)

Settings that actually work (verified against Claude Code source):

```json
{
  "model": "claude-sonnet-4-6",
  "autoCompactEnabled": true,
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "65"
  }
}
```

**`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`** — triggers compaction at N% of context capacity instead of the default (typically 85%). Set to 60-70 to compact earlier and keep context lean.

**What does NOT work:** `ignorePatterns`, `autoCompactThreshold` — these appear in blog posts but are silently ignored by Claude Code.

---

## 7. Hook Templates

### claude-ignore (PreToolUse file exclusion)

Implement `.ai/exclusions.md` enforcement via a hook. Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".path // .file_path // empty\"); [ -z \"$FILE\" ] && exit 0; grep -v \"^#\" .ai/exclusions.md 2>/dev/null | grep -v \"^$\" | while read pat; do [[ \"$FILE\" == $pat ]] && { echo \"Blocked by .ai/exclusions.md: $FILE\"; exit 1; }; done; exit 0'"
          }
        ]
      }
    ]
  }
}
```

### context-guard (warn on wide reads)

Warns when a session reads more than N files:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'COUNT=$(cat /tmp/.aicr-read-count 2>/dev/null || echo 0); COUNT=$((COUNT+1)); echo $COUNT > /tmp/.aicr-read-count; LIMIT=$(grep -A1 \"Max files\" .ai/token-budget.md 2>/dev/null | tail -1 | tr -dc 0-9); [ -n \"$LIMIT\" ] && [ \"$COUNT\" -ge \"$LIMIT\" ] && echo \"[aicr] Warning: $COUNT files read this session (limit: $LIMIT)\" >&2; exit 0'"
          }
        ]
      }
    ]
  }
}
```

---

## Validator (`validate.sh`)

Zero-dependency shell script. Validates a project follows this spec.

See [validate.sh](validate.sh).

---

## What This Is NOT

- A CLI tool
- A registry or package
- A TOML/YAML config format
- Software that requires installation

The spec is the product. Read it once, set up `.ai/`, commit it, and never think about this repo again — except when onboarding someone new.

---

## Open Questions

- Should `.ai/` folder name be configurable? Some teams prefer `.claude/` for Claude-only projects.
- Cursor uses `.cursorrules`. Copilot uses GitHub Copilot Instructions. Should `.ai/` absorb these or co-exist?
- Should CLAUDE.md at root be canonical with `.ai/` files imported by reference?
