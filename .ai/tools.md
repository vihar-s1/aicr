## Tool Permissions

| Tool        | Permission | Notes                                     |
|-------------|------------|-------------------------------------------|
| file_read   | allow      | Within scope.md boundaries only           |
| file_write  | allow      | Confirm before adding files to templates/ |
| bash        | allow      | No destructive commands without approval  |
| web_fetch   | deny       |                                           |

## Denied Commands
- `rm -rf`
- `git push --force`
- `git reset --hard`

## Standardized Tools
- Validator: `./validate.sh [dir]`
- Setup: `./setup.sh`
- Shell lint: `shellcheck *.sh templates/hooks/*.sh`

## Output Format Standards

**Spec or template changes:**
- Show the diff, not the full file
- State which consumer is affected: hooks, validate.sh, or the assistant

**Bug fixes:**
- Root cause first, then fix, then how to verify
- No preamble

**Code review:**
- Severity order: critical → warning → suggestion
- Format: `file:line — issue — fix`
