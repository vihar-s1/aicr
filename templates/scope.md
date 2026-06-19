## In-Scope
- `src/`
- `tests/`
- `docs/`
- `scripts/`

## Out-of-Scope (read-only, never modify without explicit instruction)
- `infra/`
- `.github/`
- `migrations/`

## Off-Limits (never read or modify)
- `secrets/`
- `certs/`
- `**/vendor/**`
- Anything matching exclusions.md
