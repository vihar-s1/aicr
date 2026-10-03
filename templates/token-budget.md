## Model Routing

Model IDs live in `.ai/config` (`MODEL_FAST`, `MODEL_BALANCED`, `MODEL_DEEP`).
This table maps work to a tier — it never names a model, so it doesn't rot
when a provider ships a new version.

| Task | Tier |
|---|---|
| Search, grep, file lookup, explaining code | `FAST` |
| Bug fixes, feature work, routine edits | `BALANCED` |
| Architecture, code review, complex debugging | `DEEP` |

The machine-readable form of this table is `ROUTE_FAST` / `ROUTE_BALANCED` /
`ROUTE_DEEP` in `.ai/config`. `.ai/hooks/tier-context.sh` injects it at session
start, so the policy is in context from turn one rather than hoping this file
gets read. External orchestrators read the same keys.

Claude Code: set the default in `settings.json` (`"model"`), switch mid-session
with `/model`.

## Effort Levels

Each tier carries its own effort in `.ai/config` (`EFFORT_FAST`,
`EFFORT_BALANCED`, `EFFORT_DEEP`), with `EFFORT_DEFAULT` as the fallback for
work that matches no tier.

| Tier | Effort |
|---|---|
| `FAST` | `EFFORT_FAST` |
| `BALANCED` | `EFFORT_BALANCED` |
| `DEEP` | `EFFORT_DEEP` |
| Security review, system redesign | `xhigh` |

Claude Code: set `"effortLevel"` in `settings.json`, or `/effort <level>`
mid-session. Valid values are `low`, `medium`, `high`, `xhigh`.

Only escalate when getting it right the first time saves 3+ follow-up turns.

## Context Limits

Defined in `.ai/config`: `MAX_FILES`, `WARN_FILES`, `MAX_FILE_LINES`.
`.ai/hooks/context-guard.sh` warns when a session crosses them.

`validate.sh --measure` reports what the always-loaded files actually cost per
turn and per session.

## Context Strategy

- Read specific functions or sections, not whole files
- Ask before reading more than 5 files at once
- Files over `MAX_FILE_LINES`: read only the relevant section
- Compact before switching major task contexts — don't wait for the limit

## Compaction Triggers

- After completing a PR review cycle
- Before starting work in a different subsystem
- After a long debugging session
- Before a complex multi-file refactor
