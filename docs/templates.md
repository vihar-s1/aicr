# Templates

`templates/` is the deliverable. Copy it into a project as `.ai/` and fill it in:

```bash
cp -r templates/ your-project/.ai/
mv your-project/.ai/CLAUDE.md.template your-project/.ai/CLAUDE.md
ln -s .ai/CLAUDE.md your-project/CLAUDE.md
```

The symlink exists because Claude reads `CLAUDE.md` from the project root, while
`.ai/` is the source of truth for everything else.

## What each file is for

| File | Role | Read by |
|---|---|---|
| `config` | Model tiers, effort, routing policy, context limits | hooks, `validate.sh`, orchestrators, humans |
| `CLAUDE.md` | Project context and conventions | the assistant, every turn |
| `exclusions.md` | Paths the assistant must never read | `exclude-guard.sh` |
| `scope.md` | In-scope / read-only / off-limits directories | the assistant |
| `tools.md` | Tool permissions and output format standards | the assistant |
| `token-budget.md` | Which tier and effort level fits which task | the assistant |
| `hooks/` | Enforcement scripts — see [hooks.md](hooks.md) | Claude Code |

## config is the single source of lookup

`config` is the only file that holds concrete values. The markdown files refer
to its keys by name and never restate a number or a model ID. Change a limit in
one place and the hooks, the validator, and the guidance all follow.

Each tier resolves to a triple — `MODEL_<TIER>`, `EFFORT_<TIER>`, `ROUTE_<TIER>`
— so one lookup answers "which model, how hard should it think, and what work
belongs here". The `ROUTE_*` lists make the policy machine-readable, which is
what lets `tier-context.sh` inject it and an external orchestrator consume it
without re-deriving it.

Model tiers are deliberately vendor-neutral — `MODEL_FAST`, `MODEL_BALANCED`,
`MODEL_DEEP`. A project using Cursor or Copilot fills in different IDs; a
project that switches providers edits three lines. Nothing else mentions a
model by name, so nothing else rots when a provider ships a new version.

## Filling in CLAUDE.md

Every byte is prepended to every turn, which makes it the most expensive
repeated cost in the project. Rules that matter:

1. **Hard limit: `CLAUDE_MD_MAX_LINES` (default 150).** `validate.sh` enforces it.
2. **Commands over descriptions.** `` `pnpm test` `` beats "we use vitest."
3. **Explicit over implicit.** "Never use `npm install`" beats "we prefer pnpm."
4. **Bullets, not paragraphs.**
5. **Keep `Current Focus` fresh.** A stale focus section points the assistant at
   the wrong work.
6. **Audit quarterly.** Cut anything the assistant hasn't needed in a month.

Required sections are listed in [../SPEC.md](../SPEC.md) and checked by
`validate.sh`.

Run `validate.sh --measure` to see what it actually costs. The limit exists
because this file is re-sent every turn; the measurement turns that from a
rule of thumb into a number.

## What belongs where

CLAUDE.md is for understanding the project. The other `.ai/` files are
behavioral constraints. Keep them separate — mixing them bloats the file that
gets re-read every turn.
