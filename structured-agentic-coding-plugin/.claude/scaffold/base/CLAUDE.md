# __PROJECT_NAME__

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
- `__BE_DIR__/.claude/agents/` — Backend agents (dev, reviewer, fixer)
- `__FE_DIR__/.claude/agents/` — Frontend agents (dev, reviewer, fixer)
- `__BE_DIR__/.claude/agents/be-scans/` — Backend scan playbooks
- `__FE_DIR__/.claude/agents/fe-scans/` — Frontend scan playbooks

## IMPORTANT: Dynamic Agent Discovery
Before dispatching work, orchestrator agents MUST:

1. Read `.claude/AGENTS.md` to get the current agent manifest
2. Scan the target directory's `.claude/agents/` for agent files: `Glob("{target}/.claude/agents/__PREFIX__-*.md")`
3. Read the first 3 lines of each agent file to understand its role
4. Choose the right agent based on the task requirements

## Masterplan System
For multi-step features, use the masterplan workflow:
- Say "Add [feature]" or "Build [feature]" to trigger the architect agent
- Architect asks questions, designs a structured masterplan at `docs/masterplans/`
- Executor dispatches dev agents per task, reviews incrementally, commits per phase
- Resume interrupted masterplans with "resume masterplan"

## Commands
- Frontend dev: `__FE_SERVE__`
- Backend dev: `__BE_RUN__`
- Database: `__DB_START__`
- Migrations: `__MIGRATION__`
- Format frontend: `__FE_FORMAT__`
- Format backend: `__BE_FORMAT__`
- Lint frontend: `__FE_LINT__`
- Frontend build: `__FE_BUILD__`
- Frontend tests: `__FE_TEST__`
- Backend tests: `__BE_TEST__`
- E2E tests: `__E2E_CMD__`
- Rebuild graph: `sac-graph rebuild`

## Git Conventions
- Conventional commits, title-only format
- No co-author trailers unless explicitly requested
