## Tool Permissions

| Tool      | Permission | Notes                            |
|-----------|------------|----------------------------------|
| file_read | allow      | Within app/, tests/              |
| file_write| allow      | Confirm before new files         |
| bash      | allow      | No DB drops without approval     |
| web_fetch | deny       |                                  |

## Standardized Tools
- Package manager: `uv` (never pip directly)
- Test: `uv run pytest`
- Lint: `uv run ruff check . && uv run mypy .`
- Migrate: `uv run alembic upgrade head`

## Output Format
- Errors: root cause, then fix
- New endpoints: full handler + schema + service stub
- Diffs for edits, full file for new files
