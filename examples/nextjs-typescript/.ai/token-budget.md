## Model Routing

| Task | Model |
|---|---|
| Finding files, grep, explore | Haiku |
| Bug fixes, component edits | Sonnet |
| Architecture, large refactors, review | Opus |

## Effort Levels

Default: `medium`. Use `high` for PR reviews and architecture decisions.

## Context Limits

**Max files per session:** 20
**Warn at:** 12 files
**Max file size:** 400 lines

## Context Strategy
- Server components and client components are separate concerns — don't load both for a single-side bug
- Prisma schema is the single source of truth — read it before reading model files
- Compact after finishing a feature before starting the next
