## Tool Permissions

| Tool      | Permission | Notes                                 |
|-----------|------------|---------------------------------------|
| file_read | allow      | Within src/, prisma/schema.prisma     |
| file_write| allow      | Confirm before new files              |
| bash      | allow      | No DB drops, no force-push            |
| web_fetch | deny       |                                       |

## Standardized Tools
- Package manager: `pnpm` (never npm/yarn)
- ORM: Prisma (`pnpm db:push` for schema changes)
- UI: shadcn/ui components only — no raw HTML divs for layout
- Dates: `date-fns` (never moment)

## Output Format
- New files: show full file
- Edits: diff only
- Errors: root cause first, then fix, no preamble
