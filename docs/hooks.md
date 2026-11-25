# Hooks

`.ai/exclusions.md` and the context limits in `.ai/config` are only
descriptions until something enforces them. These two hooks do the enforcing.
They ship in `templates/hooks/` and land at `.ai/hooks/` when you copy the
templates in.

| Hook | Event | Effect |
|---|---|---|
| `exclude-guard.sh` | `PreToolUse` on `Read\|Edit\|Write` | Blocks any path matching `.ai/exclusions.md` |
| `context-guard.sh` | `PostToolUse` on `Read` | Warns at `WARN_FILES`, then at `MAX_FILES` |
| `tier-context.sh` | `SessionStart` | Injects the routing policy from `.ai/config` |

## Wiring

Add to `.claude/settings.json` in the project root:

```json
{
  "hooks": {
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
    ],
    "SessionStart": [
      {
        "hooks": [{ "type": "command", "command": ".ai/hooks/tier-context.sh" }]
      }
    ]
  }
}
```

Make sure both are executable: `chmod +x .ai/hooks/*.sh`.

## How the contract actually works

Worth stating plainly, because most published versions of this hook are wrong:

- **Input arrives as JSON on stdin**, not in an environment variable. There is
  no `CLAUDE_TOOL_INPUT` — it does not exist in the Claude Code binary. The
  path lives at `.tool_input.file_path`.
- **Exit 2 blocks** the tool call and shows stderr to the assistant. Exit 1 is
  a non-blocking error: the read goes through anyway.
- **Don't parse patterns in a pipeline.** `... | while read pat; do ... exit 1; done`
  runs the loop in a subshell, so the exit kills the subshell and the hook
  still returns 0. `exclude-guard.sh` redirects from the file instead.

## tier-context.sh

`token-budget.md` describes which tier fits which work, but nothing guarantees
the assistant reads it. This hook closes that gap: at session start it reads the
`MODEL_*`, `EFFORT_*`, and `ROUTE_*` keys from `.ai/config` and returns them as
`additionalContext`, so the policy is in context from turn one.

It stays quiet when there is nothing useful to say — no config, or no tier with
a model set — rather than injecting an empty table. It needs no `jq`: it emits
its own JSON, because a session-start hook has to work on a bare machine.

```bash
echo '{}' | .ai/hooks/tier-context.sh | jq -r \
  '.hookSpecificOutput.additionalContext'
```

## Dependency

`exclude-guard.sh` needs `jq` to read the JSON payload. Without it the hook
**fails open** — it prints a warning to stderr and allows the call, rather than
blocking every file operation in the project. `validate.sh` flags a missing
`jq` so this doesn't go unnoticed.

## Pattern syntax

`exclusions.md` uses gitignore-style globs, translated to anchored regexes:

| Glob | Matches |
|---|---|
| `**/` | any depth, including none — `**/.env*` catches both `.env` and `app/.env` |
| `**` | anything, across directory boundaries |
| `*` | anything except `/` |
| `?` | one character except `/` |
| `dir/` | expands to `dir/**` (the directory's contents) |

Everything after `#` on a line is a comment. Blank lines are skipped.

Patterns match **repo-relative** paths, so they behave the same wherever the
repo is checked out.

## Testing a hook

```bash
echo '{"tool_name":"Read","tool_input":{"file_path":".env"}}' \
  | .ai/hooks/exclude-guard.sh; echo "exit=$?"    # expect exit=2

echo '{"tool_name":"Read","tool_input":{"file_path":"src/index.ts"}}' \
  | .ai/hooks/exclude-guard.sh; echo "exit=$?"    # expect exit=0
```

## Validator pre-commit hook

The Claude-side hooks above guard the assistant at read time. A separate
pre-commit hook guards the human at commit time — refusing to accept a commit
when `validate.sh` fails. Enables the AGENT_MD_MAX_LINES cap and config
consistency checks as real gates instead of advisory numbers.

Install in any project's `.git/hooks/pre-commit` (chmod +x):

```bash
#!/usr/bin/env bash
# Refuse the commit if .ai/ drifts out of spec.
exec ./validate.sh . >/dev/null
```

Three lines. `exec` replaces the shell with `validate.sh` so its exit code is
the hook's; the `>/dev/null` keeps git's commit output clean (re-run
`validate.sh .` by hand to see what failed).

Mirror as CI with one job (GitHub Actions):

```yaml
- uses: actions/checkout@v4
- run: ./validate.sh .
```

Either catches CLAUDE.md growth and config drift; both is belt-and-braces.
