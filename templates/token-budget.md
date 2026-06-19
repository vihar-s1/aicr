## Model Routing

Pick the model that matches the task. Switching mid-session: `/model <name>`.

| Task Type | Model | Command |
|---|---|---|
| Search, grep, explore, lookup | Haiku | `/model claude-haiku-4-5` |
| Bug fixes, regular coding, edits | Sonnet | `/model claude-sonnet-4-6` |
| Architecture, code review, complex debug | Opus | `/model claude-opus-4-7` |
| Explaining code, answering questions | Haiku | `/model claude-haiku-4-5` |

## Effort Levels

| Task | Effort | Command |
|---|---|---|
| Grep, lookup, one-liner | low | `/effort low` |
| Standard feature, bug fix | medium | `/effort medium` |
| Review, architecture, complex refactor | high | `/effort high` |
| Security review, system redesign | max | `/effort max` |

Default: `medium`. Only escalate when getting it right the first time saves 3+ follow-up turns.

## Context Limits

**Max files per session:** 25
**Warn at:** 15 files
**Max file size to read in full:** 400 lines

## Context Strategy

- Read specific functions or sections, not whole files
- Ask before reading more than 5 files at once
- Files over 400 lines: read only the relevant section
- Run `/compact` before switching major task contexts (finishing a debug session, starting a new feature)
- Don't wait for context limit — compact proactively

## Compaction Triggers

- After completing a PR review cycle
- Before starting work in a different subsystem
- After a long debugging session
- Before a complex multi-file refactor
