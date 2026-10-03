## In-Scope
- `templates/`
- `docs/`
- `SPEC.md`
- `README.md`
- `validate.sh`
- `setup.sh`

## Out-of-Scope (read-only, never modify without explicit instruction)
- `.ai/config`, `.ai/exclusions.md`, `.ai/hooks/` — copies of `templates/`;
  edit the template first, then re-copy
- `.ai/CLAUDE.md`, `.ai/scope.md`, `.ai/tools.md` — aicr-specific, edit directly

## Off-Limits
- Anything matching exclusions.md
