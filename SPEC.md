# aicr Specification

**Version:** 0.3
**Updated:** 2026-09-29
**Verified against:** Claude Code 2.1.236

---

## What This Is

A standard for structuring AI assistant configuration in software projects. The
`.ai/` folder works for Claude, Cursor, Copilot, and whatever comes next.
Tool-specific details live inside it; the folder itself is neutral.

Two goals, equally weighted:

1. **Config sharing** — commit it, review it, onboard from it
2. **Token control** — prevent waste: wrong model, bloated context, needless reads

---

## Directory Layout

```
<project_root>/
├── CLAUDE.md -> .ai/CLAUDE.md     # symlink; Claude reads from the root
└── .ai/
    ├── config                     # model tiers, effort, context limits
    ├── CLAUDE.md                  # project context and conventions
    ├── exclusions.md              # what the assistant must never read
    ├── scope.md                   # in-scope / read-only / off-limits
    ├── tools.md                   # tool permissions, output format standards
    ├── token-budget.md            # which tier and effort fits which task
    └── hooks/
        ├── exclude-guard.sh       # enforces exclusions.md
        ├── context-guard.sh       # warns on context budget
        └── tier-context.sh        # injects the routing policy at session start
```

Claude reads `CLAUDE.md` from the project root, so symlink it:

```bash
ln -s .ai/CLAUDE.md CLAUDE.md
```

`./setup.sh --init <dir>` does the whole scaffold, including hook wiring.

---

## 1. `config` — the single source of lookup

The only file holding concrete values. Every other file refers to its keys by
name and never restates a number or a model ID.

```
MODEL_FAST=
MODEL_BALANCED=
MODEL_DEEP=

EFFORT_FAST=low
EFFORT_BALANCED=medium
EFFORT_DEEP=high
EFFORT_DEFAULT=medium

ROUTE_FAST=search,grep,find,lookup,explain,...
ROUTE_BALANCED=fix,implement,add,edit,refactor,...
ROUTE_DEEP=review,architect,audit,security,debug,...

MAX_FILES=25
WARN_FILES=15
MAX_FILE_LINES=400
AGENT_MD_MAX_LINES=150
TURNS_PER_SESSION=40
```

Each tier resolves to a triple — `MODEL_<TIER>`, `EFFORT_<TIER>`, `ROUTE_<TIER>`
— so a consumer needs one lookup, not three. The `ROUTE_*` lists must be
disjoint; `validate.sh` fails a config where a keyword appears in two tiers.

Plain `KEY=value`: shell-sourceable and greppable, so the hooks and
`validate.sh` read it without a parser or a dependency.

**Model tiers are vendor-neutral by design.** `FAST` / `BALANCED` / `DEEP`
describe the work, not the vendor. A project on a different assistant fills in
different IDs; a project switching providers edits three lines. No other file
names a model, so nothing else rots when a provider ships a new version.
`validate.sh` fails a `token-budget.md` that hardcodes a model ID.

---

## 2. Exclusions (`exclusions.md`)

Gitignore-style globs the assistant must not read, reference, or pull into
context. A hard boundary, not a suggestion.

Covers secrets, generated output, lockfiles, binary assets, and internal docs.
Syntax and matching semantics: [docs/hooks.md](docs/hooks.md).

**Enforcement is not optional.** Without `hooks/exclude-guard.sh` wired up, this
file is a comment. See §6.

---

## 3. Token Budget (`token-budget.md`)

Maps work to a tier and an effort level. Highest-leverage file in the spec,
because model choice dominates cost.

| Task | Tier |
|---|---|
| Search, grep, lookup, explaining code | `FAST` |
| Bug fixes, feature work, routine edits | `BALANCED` |
| Architecture, code review, complex debugging | `DEEP` |

Each tier carries its own effort (`EFFORT_FAST`, `EFFORT_BALANCED`,
`EFFORT_DEEP`), with `EFFORT_DEFAULT` for work matching no tier.

Escalate only when getting it right the first time saves 3+ follow-up turns.

**The routing policy is machine-readable.** `ROUTE_*` exists so the mapping is
consumed, not just read: `tier-context.sh` injects it at session start, and an
external orchestrator can resolve a tier without re-deriving the policy. One
declaration, several consumers — which is the whole reason `.ai/` is a shared
convention rather than a private notes file.

The file also carries context strategy and compaction triggers. Numeric limits
come from `config`, never from this file.

---

## 4. Tool Permissions (`tools.md`)

An allow/deny table for tool use, a denied-command list that holds even when
`bash` is allowed, the project's standardized tooling, and output format
standards per task type (bug fixes, refactors, new features, code review).

Output format standards belong here rather than in `CLAUDE.md`: they are
behavioral constraints, and `CLAUDE.md` pays for its length every turn.

---

## 5. Scope (`scope.md`)

Three tiers, in descending permission:

- **In-Scope** — read and modify freely
- **Out-of-Scope** — read-only; modify only on explicit instruction
- **Off-Limits** — never read or modify

`scope.md` is advisory to the assistant. `exclusions.md` is the enforced layer;
anything that must not be read belongs there too.

---

## 6. Enforcement (`hooks/`)

| Hook | Event | Effect |
|---|---|---|
| `exclude-guard.sh` | `PreToolUse` on `Read\|Edit\|Write` | Blocks paths matching `exclusions.md` (exit 2) |
| `context-guard.sh` | `PostToolUse` on `Read` | Warns at `WARN_FILES`, then `MAX_FILES` |
| `tier-context.sh` | `SessionStart` | Returns the routing policy as `additionalContext` |

The contract, the wiring JSON, the `jq` dependency, and how to test a hook:
[docs/hooks.md](docs/hooks.md).

Three things most published versions of this hook get wrong — stated here
because they make the difference between working and silently doing nothing:
input arrives as **JSON on stdin** (there is no `CLAUDE_TOOL_INPUT`
environment variable); **exit 2 blocks** while exit 1 lets the call through;
and a `while read` loop **in a pipeline** runs in a subshell, so exiting from
inside it never reaches the hook's exit status.

---

## 7. Assistant Settings

For Claude Code, verified against 2.1.236:

```json
{
  "model": "sonnet",
  "effortLevel": "medium",
  "autoCompactEnabled": true,
  "env": { "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "65" }
}
```

`config` is what humans and the validator read; `settings.json` is what the
tool reads. Keep them in sync with `.ai/bin/sync-settings.sh`, which resolves
the BALANCED tier (`MODEL_BALANCED`, `EFFORT_DEFAULT`) and merges `model` +
`effortLevel` into `.claude/settings.json` without touching other keys.
`--check` returns non-zero if they have drifted — run it in CI.

`ignorePatterns` and `autoCompactThreshold` are **not** settings keys, despite
circulating widely. Use the hook in §6 to exclude files.

---

## 8. `CLAUDE.md`

Read at the start of every session and prepended every turn, which makes it the
most expensive repeated cost in the project.

Required sections: **What This Is**, **Architecture**, **Development Commands**,
**Conventions**, **What NOT To Do**, **Current Focus**.

Hard limit: `AGENT_MD_MAX_LINES` (default 150), enforced by `validate.sh`.

Writing rules and the rationale: [docs/templates.md](docs/templates.md).

**What goes where:** `CLAUDE.md` is for understanding the project. Everything
else in `.ai/` is a behavioral constraint. Mixing them bloats the one file that
gets re-read every turn.

**Anti-patterns that cause CLAUDE.md to grow past the limit** — each belongs
elsewhere:

| Pattern | Where it belongs |
|---|---|
| Tool usage examples, command recipes beyond 3 lines | `tools.md` or `docs/` |
| Skill inventories, one-line-per-skill summaries | a separate index file, referenced |
| Historical decision records / ADR-style context | `docs/` or git log |
| Per-contributor or team conventions | team docs, not assistant context |
| Setup / install instructions beyond 1–2 lines | `README.md` |
| Workflow recipes ("to deploy, run X then Y then Z") | `docs/` |
| Important-sounding callouts repeated across sections | pick one home, link from the others |

The validator flags every single H2 section over 40 lines even when the file
total is still under the limit — a bloated section squeezes the required ones
and is the usual shape of growth before the hard cap fires.

---

## Validation

`./validate.sh [dir]` — zero dependencies, exit 0 on pass. Checks structure,
`config` keys and their internal consistency, routing-keyword disjointness,
required sections, hook installation and wiring, `CLAUDE.md` length (total
and per-H2-section), and `.gitignore` coverage for secrets.

**Wire it as a gate.** The validator is advisory until something runs it on
every change. Two recommended integrations:

- **Pre-commit hook.** `docs/hooks.md` shows the three-line `.git/hooks/pre-commit`
  that refuses a commit when the validator fails.
- **CI.** For GitHub Actions, one job suffices:

  ```yaml
  - uses: actions/checkout@v4
  - run: ./validate.sh .
  ```

  This catches CLAUDE.md growth and config drift at PR time, which is the
  only moment where enforcement is cheap.

`./validate.sh --measure [dir]` reports what the always-loaded files cost per
turn and per session. `CLAUDE.md` is re-sent every turn, so it is the only file
whose size compounds — this is what makes the 150-line limit a measurement
rather than a guess. Counts are estimated at ~3.7 chars/token; for an exact
figure use the Anthropic API's `count_tokens` endpoint (not `tiktoken`, which
is OpenAI's tokenizer and will not match).

This repo passes its own validator. That is a requirement, not a nicety.

---

## What This Is NOT

A CLI, a registry, a package, or a config format. Two shell scripts and a
folder of markdown. Read the spec once, set up `.ai/`, commit it, and never
think about this repo again — except when onboarding someone new.

---

## Roadmap

**Phase 2 — cross-assistant generators.** Ship `.ai/bin/emit-cursor.sh` and
`.ai/bin/emit-copilot.sh` as explicit, scripted one-shots: read `.ai/CLAUDE.md`
plus `.ai/tools.md` and write `.cursorrules` and `.github/copilot-instructions.md`
at the project root. Scripts, not daemons — the author re-runs them after
editing `.ai/`, same as `sync-settings.sh`. `validate.sh --check` verifies the
generated files are current. `.ai/` stays the single source of truth; the
emitted files are build artifacts and should be gitignored or regenerated in
CI, not hand-edited.
