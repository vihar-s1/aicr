## Model Routing

| Task | Model |
|---|---|
| Grepping for types/interfaces, lookup | Haiku |
| Handler/service implementation | Sonnet |
| Concurrency design, API design review | Opus |

## Effort Levels

Default: `medium`. Use `high` for concurrency-sensitive code and error handling design.

## Context Limits

**Max files per session:** 20
**Max file size:** 500 lines (Go files tend to be longer)

## Context Strategy
- internal/ is off-limits to callers by design — read only the package relevant to the task
- Interfaces are defined at call sites in Go — read the caller to understand the interface before reading the implementation
- Compact between handler work and middleware work
