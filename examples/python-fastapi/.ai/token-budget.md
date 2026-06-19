## Model Routing

| Task | Model |
|---|---|
| Finding endpoints, grep | Haiku |
| Adding endpoints, fixing bugs | Sonnet |
| Service design, data model review | Opus |

## Effort Levels

Default: `medium`. Use `high` for data model design and security-related changes.

## Context Limits

**Max files per session:** 20
**Max file size:** 300 lines (FastAPI files should stay small by layer separation)

## Context Strategy
- Layer separation is enforced — read one layer at a time
- Pydantic schemas are ground truth for request/response shape — read schemas before handlers
- Compact after completing each endpoint group
