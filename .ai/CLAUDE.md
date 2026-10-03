# aicr

## What This Is
A convention for structuring AI assistant configuration in software projects:
a `.ai/` folder any assistant can be pointed at. Markdown plus Bash — the spec
is the product, not the tooling.

## Architecture
- `SPEC.md` — the specification; the authoritative document
- `templates/` — the deliverable unit, copied into a project as `.ai/`
- `templates/hooks/` — enforcement scripts (block excluded reads, warn on budget, inject routing policy)
- `docs/` — guides for the templates, hooks, and token-optimization tooling
- `validate.sh` — zero-dependency validator for a project's `.ai/`
- `setup.sh` — installs token-optimization tooling into Claude Code

## Development Commands
- Validate this repo: `./validate.sh .`
- Measure always-loaded cost: `./validate.sh --measure .`
- Validate a project: `./validate.sh ../some-project`
- Lint shell: `shellcheck validate.sh setup.sh templates/hooks/*.sh`
- Test a hook: see `docs/hooks.md`

## Conventions
- `templates/config` is the only place concrete values live; markdown refers to keys
- Never name a model in a template — use the `MODEL_FAST`/`BALANCED`/`DEEP` tiers
- Claude Code behavior is verified against the installed binary before documenting
- `.ai/` here is a copy of `templates/` — change the template, then re-copy

## What NOT To Do
- No per-stack example folders — they duplicate `templates/` and drift
- No changelog or diff markdown committed to the repo
- Never document a setting or hook contract without verifying it first
- No hardcoded model IDs outside `config`

## Current Focus
Phase 1 complete: machine-readable routing policy in `config`, `tier-context.sh`
injecting it at session start, and `validate.sh --measure` reporting per-turn
cost. Routing policy is consumed by aicr and, later, an external orchestrator.
