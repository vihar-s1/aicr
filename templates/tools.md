## Tool Permissions

| Tool        | Permission | Notes                                      |
|-------------|------------|--------------------------------------------|
| file_read   | allow      | Within scope.md boundaries only            |
| file_write  | allow      | Confirm before writing new files           |
| bash        | allow      | No destructive commands without approval   |
| web_fetch   | deny       |                                            |
| browser     | deny       |                                            |

## Denied Commands
- `rm -rf`
- `git push --force`
- `git reset --hard`
- `DROP TABLE` or any destructive DB command without explicit confirmation
- Package installs without approval

## Standardized Tools
- Package manager: <your-choice>
- Test runner: <your-choice>
- Linter: <your-choice>
- Build: <your-choice>

## Output Format Standards

**Bug fixes:**
- State root cause first, then fix, then prevention
- Show fix as a diff, not the full file
- No preamble ("Sure! I'll fix that...")

**Refactoring:**
- Show before/after diff
- One-line note on what changed and why
- Do not touch unrelated code in the same commit

**New features:**
- Full file for new files; diff for edits
- Create or update tests if test files exist nearby
- Update docs if a docs/ file covers the area

**Code review:**
- List by severity: critical → warning → suggestion
- Format: `file:line — issue — recommended fix`
- No praise, no filler

**Explanations:**
- Bullet points, not paragraphs
- Lead with the answer, then reasoning
