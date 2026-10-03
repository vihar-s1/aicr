# Token Optimization

The `.ai/` spec controls what the assistant reads. This covers the layer below
it: tooling that shrinks what a read actually costs.

`setup.sh` installs the automated set. Everything else here is optional and
manual.

> Savings percentages below are the figures each project publishes. They are
> vendor claims, not measurements taken in this repo. Measure against your own
> workload before relying on any of them.

## Installed by `setup.sh`

| Tool | What it does | Activates |
|---|---|---|
| [RTK](https://github.com/rtk-ai/rtk) | Compresses CLI output before it reaches the context | Automatic, via a `PreToolUse` hook on Bash |
| [Caveman](https://github.com/JuliusBrussee/caveman) | Cuts output verbosity | `/caveman` in a session |
| [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) | Tree-sitter knowledge graph; answers structural queries without reading files | Ask the assistant to "index this project" |
| [Headroom](https://pypi.org/project/headroom-ai/) | Context-compression proxy wrapping the `claude` binary | Immediately; reverse with `headroom unwrap claude` |

`setup.sh` also prints the two `/plugin` commands for
[context-mode](https://github.com/mksglu/context-mode), which sandboxes tool
output. That one can't be installed from a shell — it needs an interactive
Claude Code session.

Run `./setup.sh --help` for flags. It is idempotent and backs up
`~/.claude/settings.json` before every mutation.

## Optional — MCP servers

| Server | Use it when |
|---|---|
| [Context7](https://github.com/upstash/context7) | The assistant keeps getting a library's API wrong because of version drift. Fetches version-pinned docs per query. |
| [Code Context Engine](https://mcpservers.org/servers/elara-labs/code-context-engine) | Finding one symbol costs 10+ file reads. Serves an AST index instead. |
| [Repomix](https://repomix.com) | Onboarding onto an unfamiliar codebase. |

## Optional — CLI

```bash
# Structural summary of a repo: signatures only, comments stripped
npx repomix --compress --remove-comments --token-count-tree

# What the always-loaded files cost, per turn and per session
./validate.sh --measure .
```

`--measure` estimates at ~3.7 chars/token. For an exact count, use the
Anthropic API's `count_tokens` endpoint — **not `tiktoken`**, which is OpenAI's
tokenizer and does not match Claude's.

## Claude Code settings

Verified against the Claude Code binary, v2.1.236:

```json
{
  "model": "sonnet",
  "effortLevel": "medium",
  "autoCompactEnabled": true,
  "env": { "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "65" }
}
```

| Key | Effect |
|---|---|
| `model` | Default model for new sessions; `/model` overrides mid-session |
| `effortLevel` | Reasoning depth: `low`, `medium`, `high`, `xhigh`. `/effort` overrides mid-session |
| `autoCompactEnabled` | Auto-compaction; on by default |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | Compact at N% of context instead of the default. 60–70 keeps context lean |

**Not real settings:** `ignorePatterns` and `autoCompactThreshold` circulate in
blog posts but are not settings keys — `ignorePatterns` appears in the binary
only as an unrelated internal identifier. To exclude files, use the hook in
[hooks.md](hooks.md).

## Picking a fix

| Symptom | Fix |
|---|---|
| Assistant reads secrets or generated files | `exclude-guard.sh` — [hooks.md](hooks.md) |
| 15+ file reads to answer one question | codebase-memory-mcp or Code Context Engine |
| Wrong library API, repeatedly | Context7 |
| Context fills mid-session | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=65` plus `/compact` discipline |
| Deep model used for trivial work | Model tiers in `.ai/config` plus `/model` |
| Verbose CLI output eating context | RTK |
