# API Service

## What This Is
A FastAPI service (Python 3.12) providing REST endpoints for the data processing pipeline. SQLAlchemy ORM, PostgreSQL, Redis for caching. Deployed on Railway.

## Architecture
- `app/api/` — Route handlers, one file per resource
- `app/services/` — Business logic, no DB access
- `app/repositories/` — DB access layer, SQLAlchemy models
- `app/schemas/` — Pydantic request/response schemas
- `app/core/` — Config, db connection, auth

## Development Commands
- Install: `uv sync`
- Dev: `uv run uvicorn app.main:app --reload`
- Test: `uv run pytest`
- Lint: `uv run ruff check . && uv run mypy .`
- Migrate: `uv run alembic upgrade head`

## Conventions
- All endpoints: typed request + response schemas
- Services: no SQLAlchemy imports — call repositories only
- Repositories: no business logic — DB access only
- Errors: raise `HTTPException` with explicit status codes and messages

## What NOT To Do
- No `Any` type unless unavoidable — use Pydantic models
- No raw SQL — always use SQLAlchemy ORM
- Never modify alembic migration files after they're committed
- No `print()` for logging — use `structlog`

## Current Focus
Adding webhook ingestion endpoint. Active: `app/api/webhooks.py`, `app/services/webhook_processor.py`
