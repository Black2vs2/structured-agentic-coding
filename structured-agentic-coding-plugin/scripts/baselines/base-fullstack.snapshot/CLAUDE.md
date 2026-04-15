# Test Base

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

All commands output JSON. Use graph tools first for structural queries. If a command fails, fall back to Grep immediately — do not retry. Also use Grep for: translation keys, route strings, config values, environment variables.

## Static Analysis (Optional)

If configured, these tools enhance code review:
- **SonarQube** — quality metrics, code smells, security hotspots
- **Semgrep** — structural pattern matching, custom rules
- **Sentry** — production error tracking, deployment health

## Coding Standards
Rules are enforced by code review agents:
- `.claude/rules/fe-rules.json` — Frontend rules
- `.claude/rules/be-rules.json` — Backend rules

Agent manifest (auto-generated):
- `.claude/AGENTS.md` — full list of all agents with roles and locations

Agent directories:
- `.claude/agents/codebase/` — cross-cutting agents (masterplan, docs)
- `.claude/agents/domain/` — project-specific agents (research, impact, testing)
- `backend/.claude/agents/` — Backend agents (dev, reviewer, fixer)
- `frontend/.claude/agents/` — Frontend agents (dev, reviewer, fixer)
- `backend/.claude/agents/be-scans/` — Backend scan playbooks
- `frontend/.claude/agents/fe-scans/` — Frontend scan playbooks

## IMPORTANT: Dynamic Agent Discovery
Before dispatching work, orchestrator agents MUST:

1. Read `.claude/AGENTS.md` to get the current agent manifest
2. Scan the target directory's `.claude/agents/` for agent files: `Glob("{target}/.claude/agents/testbase-*.md")`
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

## Commands
- Frontend dev: `npm run dev`
- Backend dev: `echo run`
- Database: `echo db`
- Migrations: `echo mig`
- Format frontend: `npm run format`
- Format backend: `echo format`
- Lint frontend: `npm run lint`
- Frontend build: `npm run build`
- Frontend tests: `npm run test`
- Backend tests: `echo test`
- E2E tests: `echo e2e`
- Rebuild graph: `sac-graph rebuild`

## Git Conventions
- Conventional commits, title-only format
- No co-author trailers unless explicitly requested
