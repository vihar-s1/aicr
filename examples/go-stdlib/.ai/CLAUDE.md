# Go Service

## What This Is
A Go 1.23 HTTP service using stdlib only (no frameworks). PostgreSQL via pgx, structured logging via slog. Minimal dependency policy — every new dep requires a reason.

## Architecture
- `cmd/server/` — Entry point, server setup
- `internal/handler/` — HTTP handlers, one file per resource group
- `internal/service/` — Business logic
- `internal/store/` — DB access, pgx queries
- `internal/model/` — Shared types, no logic

## Development Commands
- Install: `go mod download`
- Dev: `go run ./cmd/server`
- Test: `go test ./...`
- Lint: `golangci-lint run`
- Build: `go build -o bin/server ./cmd/server`

## Conventions
- Errors: wrap with `fmt.Errorf("context: %w", err)`, never discard
- HTTP handlers: validate input, call service, return JSON
- No `panic` except in `main()` for fatal startup errors
- Test files: `_test.go` suffix, table-driven tests

## What NOT To Do
- No globals except logger and db pool (initialized in main)
- No ORM — raw pgx queries only
- Never use `interface{}` — use concrete types or `any` with a comment
- No goroutines inside handlers — async work via background worker

## Current Focus
Adding rate limiting middleware. Active: `internal/middleware/ratelimit.go`
