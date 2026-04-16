# Test Refine NestJS Query FE

## Code Graph

CLI graph tools for structural codebase navigation. Provided by `sac-graph` — auto-indexes on first use.

Available commands (run via Bash tool):
- `sac-graph find-symbol <name> [--kind class|function|type|file|test] [--limit N]` — locate symbols by name (ranked: exact > prefix > contains)
- `sac-graph module-summary <path> [--depth 1|2|3]` — directory overview (depth=1: counts, depth=2: details, depth=3: full)
- `sac-graph dependencies <symbol>` — what does a symbol depend on?
- `sac-graph dependents <symbol>` — what depends on a symbol?
- `sac-graph blast-radius <target>... [--max-depth N]` — affected files, symbols, tests, and config references
- `sac-graph test-coverage <symbol>` — which tests cover a symbol? (name-based confidence)
- `sac-graph changes-since <commit>` — symbols added/modified/deleted since a commit
- `sac-graph rebuild` — rebuild the index

All commands output JSON. Use graph tools first for structural queries. If a command fails, fall back to Grep immediately — do not retry. Also use Grep for: translation keys, route strings, config values, environment variables.

## Static Analysis (Optional)

If configured, these tools enhance code review:
- **SonarQube** — quality metrics, code smells, security hotspots
- **Semgrep** — structural pattern matching, custom rules
- **Sentry** — production error tracking, deployment health

## Coding Standards

Stack-specific rules are enforced by code review agents. See the Backend/Frontend sections below for scope-specific rule files.

Agent manifest (auto-generated):
- `.claude/AGENTS.md` — full list of all agents with roles and locations

Agent directories:
- `.claude/agents/codebase/` — cross-cutting agents (masterplan, docs)
- `.claude/agents/domain/` — project-specific agents (research, impact, testing)

## IMPORTANT: Dynamic Agent Discovery
Before dispatching work, orchestrator agents MUST:

1. Read `.claude/AGENTS.md` to get the current agent manifest
2. Scan the target directory's `.claude/agents/` for agent files: `Glob("{target}/.claude/agents/testrnq-*.md")`
3. Read the first 3 lines of each agent file to understand its role
4. Choose the right agent based on the task requirements

## Masterplan System
For multi-step features, use the masterplan workflow via slash commands:
- `/masterplan architect <feature>` — design a masterplan through interactive Q&A
- `/masterplan execute <path>` — execute a masterplan file with dev agents
- `/masterplan review <path>` — audit a completed masterplan against the repo
- `/masterplan resume` — find and resume the most recent incomplete masterplan
- `/masterplan <feature>` — full lifecycle: architect → confirm → execute

Also triggers on: "Add [feature]", "Build [feature]", "Implement [feature]"

Agent definitions: `.claude/agents/codebase/*-masterplan-{architect,executor,reviewer}.md`
Masterplans: `docs/masterplans/` | Executed: `docs/masterplans/executed/`

## Git Conventions
- Conventional commits, title-only format
- No co-author trailers unless explicitly requested

## Frontend

Rules: `.claude/rules/fe-rules.json` — enforced by frontend code review agents.

Agent directories:
- `./.claude/agents/` — Frontend agents (dev, reviewer, fixer)
- `./.claude/agents/fe-scans/` — Frontend scan playbooks

Commands:
- Dev: `bun run dev`
- Build: `bun run build`
- Test: `bun run test`
- Format: `bun run format`
- Lint: `bun run lint`
- E2E tests: `bun run test:e2e`
<!--
Profile CLAUDE.md overlay for refine-nestjs-query-fe. Appended to
CLAUDE.md after the base fragments so Refine/GraphQL/shadcn specifics
live with the profile.
-->

### Refine.dev framework

- App composition (`src/App.tsx`) wraps `<Refine>` with providers: `dataProvider` (`@refinedev/nestjs-query`), `authProvider` (Firebase), `routerProvider` (`@refinedev/react-router`), `i18nProvider`, `accessControlProvider`, `notificationProvider`. Do NOT bypass these for ad-hoc fetch calls.
- Resources are registered in `<Refine resources={[...]}>`. Each resource has its own directory under `src/resources/<name>/` with pages + hooks + queries.
- Use `useTranslation` from `@refinedev/core`, NEVER from `react-i18next` directly. Translation keys follow `pages.<resource>.<section>.<key>`.

### GraphQL & codegen

- Operations stored as **inline** `` gql`...` `` template tags in `.ts` / `.tsx` files — no standalone `.graphql` files.
- Codegen command: `bun run codegen`. Schema source configured in `graphql.config.ts` (also tracked as `GRAPHQL_SCHEMA_SRC` in the scaffold manifest; accepts a URL for remote introspection or a local file path).
- Auto-generated types land in `src/graphql/schema.types.ts` and `src/graphql/types.ts`. **Never hand-edit** — regen via `bun run codegen`.
- `vite-plugin-graphql-codegen` runs codegen automatically on dev server start and on operation file watch.

### Forms & validation

- `react-hook-form` + `@hookform/resolvers/zod`. **Always import Zod from `zod/v4`**, never from `zod` (Zod v4 is a separate import path).
- Custom error mapping lives in `src/lib/form-validation.ts` and wires i18n keys through the Zod error map.

### Styling

- shadcn/ui (style "new-york") + Radix primitives + Tailwind 4 via `@tailwindcss/vite`. CSS variables for brand colors are declared in `src/index.css` — use those, do not hardcode hex values in components.
- Emotion is present for legacy reasons but secondary — prefer Tailwind + shadcn patterns.

### Environment & protected paths

- Env vars: only `import.meta.env.VITE_*`, typed in `src/vite-env.d.ts`. No `process.env.*`.
- Protected (never hand-edit): `src/graphql/schema.types.ts`, `src/graphql/types.ts` (auto-generated), `patches/` (dependency patches for Refine).

### Commands

- Dev: `bun run dev`
- Build (prod): `bun run build`
- Build (staging): `bun run build:stage`
- Typecheck: `bun run tsc`
- Lint (check): `bun run lint`
- Lint (autofix): `bun run lint:fix`
- Format: `bun run format`
- GraphQL codegen: `bun run codegen`
- Tests (Vitest): `bun run test`
- E2E tests: `bun run test:e2e`

