# Plugin Ecosystem

Tools and MCP servers that reduce token usage. All entries are confirmed-real as of 2026-06.

---

## MCP Servers

### Context7
**What it does:** Resolves version-specific library/framework documentation on demand instead of embedding it in context.  
**Token impact:** Eliminates "load entire node_modules to understand the API" patterns. Docs are fetched per-query, not pre-loaded.  
**Best for:** Projects using libraries where the AI keeps getting the API wrong (version drift).  
**Install:**
```bash
# In Claude Desktop or Claude Code MCP settings
npx @upstash/context7-mcp
```

---

### Token Optimizer MCP
**What it does:** Smart replacements for Read/Grep/Glob tool calls with Brotli-compressed, SQLite-cached variants.  
**Token impact:** 60-90% reduction on file operations; 83-95% on API responses.  
**Best for:** Large codebases where the AI reads many files per session.  
**Source:** [github.com/ooples/token-optimizer-mcp](https://github.com/ooples/token-optimizer-mcp)  
**Install:**
```bash
npx token-optimizer-mcp
```

---

### Code Context Engine
**What it does:** Local MCP server with AST-aware indexing and semantic search over the codebase.  
**Token impact:** ~94% savings — the AI queries a semantic index instead of reading files.  
**Best for:** Any project where the AI frequently reads 10+ files to find a symbol or understand a flow.  
**Source:** [mcpservers.org/servers/elara-labs/code-context-engine](https://mcpservers.org/servers/elara-labs/code-context-engine)

---

### Repomix MCP
**What it does:** Packages codebases into dense, AI-readable bundles. The MCP server variant exposes semantic search over the bundle.  
**Token impact:** 70% reduction using Tree-sitter-based structural compression.  
**Best for:** Onboarding a new codebase fast, or sessions where you need broad cross-file awareness.  
**Source:** [repomix.com](https://repomix.com)  
**CLI usage (no MCP needed):**
```bash
npx repomix --compress --remove-comments --output context.txt
# Then: "Here's the codebase: $(cat context.txt)"
```

---

## Hooks

### claude-ignore (PreToolUse exclusion enforcement)

Enforces `.ai/exclusions.md` at the tool layer. Files matching exclusion patterns are blocked before the AI reads them.

Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".path // .file_path // empty\"); [ -z \"$FILE\" ] && exit 0; grep -v \"^#\" .ai/exclusions.md 2>/dev/null | grep -v \"^$\" | while read pat; do case \"$FILE\" in $pat) echo \"[aicr] Blocked by exclusions.md: $FILE\"; exit 1;; esac; done; exit 0'"
          }
        ]
      }
    ]
  }
}
```

**Note:** `.claudeignore` is not a native Claude Code feature as of 2026-06. This hook is the correct implementation path. Community reference: [github.com/li-zhixin/claude-ignore](https://github.com/li-zhixin/claude-ignore).

---

### context-guard (session read counter)

Warns when reads exceed the limit defined in `token-budget.md`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'COUNT=$(cat /tmp/.aicr-reads-$$ 2>/dev/null || echo 0); COUNT=$((COUNT+1)); echo $COUNT > /tmp/.aicr-reads-$$; LIMIT=$(grep -A1 \"Max files\" .ai/token-budget.md 2>/dev/null | grep -o \"[0-9]*\" | head -1); [ -n \"$LIMIT\" ] && [ \"$COUNT\" -ge \"$LIMIT\" ] && echo \"[aicr] $COUNT files read this session (budget: $LIMIT)\" >&2; exit 0'"
          }
        ]
      }
    ]
  }
}
```

---

## Claude Code Settings

Settings that are confirmed to work (not blog-fiction):

```json
{
  "model": "claude-sonnet-4-6",
  "autoCompactEnabled": true,
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "65"
  }
}
```

| Setting | Effect | Notes |
|---|---|---|
| `autoCompactEnabled` | Enables auto-compaction | Default is `true` |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | Trigger compaction at N% of context | Set 60-70 to compact early |
| `model` | Default model for new sessions | Override with `/model` mid-session |

**Does NOT work:** `ignorePatterns`, `autoCompactThreshold` — silently ignored.

---

## CLI Tools (no MCP)

### repomix `--compress`
```bash
npx repomix --compress --remove-comments --token-count-tree
```
Tree-sitter parses the repo and emits only structural information (class/function signatures, interfaces). ~70% token reduction for "understand this codebase" prompts.

### tiktoken (token counting before sending)
```bash
pip install tiktoken
python -c "import tiktoken; enc = tiktoken.get_encoding('cl100k_base'); print(len(enc.encode(open('file.py').read())))"
```
Use it to measure CLAUDE.md, scope.md, and other always-loaded files before committing them.

---

## Decision Guide

| Problem | Tool |
|---|---|
| AI reads wrong version of a library's API | Context7 MCP |
| AI reads 15+ files per session on a large codebase | Code Context Engine MCP or Token Optimizer MCP |
| Need to onboard AI on an unfamiliar codebase fast | repomix --compress |
| AI keeps reading secrets or generated files | claude-ignore hook |
| Context fills up mid-session | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=65` + `/compact` discipline |
| Wrong model for the task | Model routing in token-budget.md + `/model` mid-session |
