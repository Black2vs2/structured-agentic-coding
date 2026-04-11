# __PROJECT_NAME__

## Codebase Understanding
Read the codemaps for project structure and domain knowledge:
- `CODEMAP.md` — architecture, tech stack, commands
- `__FE_DIR__/CODEMAP.md` — frontend file map
- `__BE_DIR__/CODEMAP.md` — backend file map

## Coding Standards
Rules are enforced by code review agents:
- `.claude/rules/fe-rules.json` — Frontend rules
- `.claude/rules/be-rules.json` — Backend rules

Agent manifest (auto-generated, single source of truth):
- `.claude/AGENTS.md` — full list of all agents with roles and locations

Agent directories:
- `.claude/agents/codebase/` — cross-cutting agents (masterplan, codemap, docs)
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

This ensures agents are always discovered from the filesystem, not from a stale hardcoded list.

## Masterplan System
For multi-step features, use the masterplan workflow:
- Say "Add [feature]" or "Build [feature]" to trigger the architect agent
- Architect asks questions, designs a structured masterplan at `docs/masterplans/`
- Executor dispatches dev agents per task, reviews incrementally, commits per phase
- Resume interrupted masterplans with "resume masterplan"

## Update Codemaps
Use `/update-codemaps` to update all structural docs:
- Default: incremental update (only files changed since last update)
- `/update-codemaps --force`: full scan and regeneration
- Agent manifest (`.claude/AGENTS.md`) is always regenerated

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

## Git Conventions
- Conventional commits, title-only format
- No co-author trailers unless explicitly requested
