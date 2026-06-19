# aicr — AI Config Repo

A spec for structuring AI assistant configuration in software projects. Not a platform, not a CLI, not a TOML format. A **convention** — like `.editorconfig` or `.prettierrc`.

Drop a `.ai/` folder into any project. Point any AI assistant at it. Done.

---

## Why

Two problems with AI assistant usage in real projects:

1. **No shared config** — every developer sets up their own Claude/Cursor/Copilot guardrails from scratch, inconsistently
2. **Token waste** — AI reads things it shouldn't, uses the wrong model for the task, bloats context, and costs more than necessary

This spec fixes both.

---

## Quickstart

```bash
# 1. Copy the templates into your project
cp -r templates/ your-project/.ai/

# 2. Edit .ai/CLAUDE.md — describe your project
# 3. Edit .ai/exclusions.md — what the AI must not read
# 4. Validate
./validate.sh your-project/
```

---

## Spec Files

| File | Purpose |
|---|---|
| `.ai/CLAUDE.md` | Project context + conventions (read by Claude every turn) |
| `.ai/exclusions.md` | Files/folders the AI must not read |
| `.ai/tools.md` | Allowed/denied tools + output format standards |
| `.ai/scope.md` | Which dirs are in/out of scope |
| `.ai/token-budget.md` | Model routing, effort levels, context limits |

Full spec: [SPEC.md](SPEC.md)

---

## Project Structure

```
aicr/
├── SPEC.md                      # Full specification
├── validate.sh                  # Validator script (zero deps)
├── templates/                   # Copy-paste starter for any project
│   ├── CLAUDE.md.template
│   ├── exclusions.md
│   ├── tools.md
│   ├── scope.md
│   └── token-budget.md
├── examples/                    # Complete .ai/ setups per stack
│   ├── nextjs-typescript/
│   ├── python-fastapi/
│   └── go-stdlib/
└── plugins/
    └── README.md                # MCP servers + tools that reduce tokens
```

---

## Language/Framework

Markdown + Bash. The "software" is one shell script. The rest is documentation.

> Convention-first: the product is the spec, not the tooling.
