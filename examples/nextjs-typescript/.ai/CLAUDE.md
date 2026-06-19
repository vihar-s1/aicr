# My App

## What This Is
A Next.js 14 SaaS application with TypeScript and App Router. Prisma ORM, PostgreSQL. Used by internal teams at Acme Corp for project management.

## Architecture
- `src/app/` — App Router pages, layouts, server components
- `src/components/` — Shared UI (shadcn/ui based)
- `src/lib/` — Utilities, db client, auth helpers
- `src/server/actions/` — Server actions, one file per entity
- `prisma/` — Schema and migrations (never modify migrations directly)

## Development Commands
- Install: `pnpm install`
- Dev: `pnpm dev`
- Test: `pnpm test`
- DB push: `pnpm db:push`
- Lint: `pnpm lint`

## Conventions
- Components: PascalCase, co-located with styles
- Server actions: `src/server/actions/<entity>Actions.ts`, return `{ data, error }`
- Imports: always `@/` alias, never `../../`
- No `useEffect` for data fetching — use server components or SWR

## What NOT To Do
- No `any` type — use `unknown` and narrow
- No direct DB calls from client components — use server actions
- Never modify `prisma/migrations/` directly
- Never `npm install` — use `pnpm`

## Current Focus
Implementing the billing module. Active files: `src/app/billing/`, `src/server/actions/billingActions.ts`
