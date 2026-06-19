## Tool Permissions

| Tool      | Permission | Notes                              |
|-----------|------------|------------------------------------|
| file_read | allow      | Within internal/, cmd/, pkg/       |
| file_write| allow      | Confirm before new files           |
| bash      | allow      | No destructive ops without confirm |
| web_fetch | deny       |                                    |

## Standardized Tools
- Build: `go build ./...`
- Test: `go test ./...`
- Lint: `golangci-lint run`
- Deps: `go mod tidy`

## Output Format
- New files: full file
- Edits: diff
- Errors: root cause + fix + how to verify it's fixed
