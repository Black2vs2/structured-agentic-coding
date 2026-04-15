
## Backend

Rules: `.claude/rules/be-rules.json` — enforced by backend code review agents.

Agent directories:
- `__BE_DIR__/.claude/agents/` — Backend agents (dev, reviewer, fixer)
- `__BE_DIR__/.claude/agents/be-scans/` — Backend scan playbooks

Commands:
- Dev: `__BE_RUN__`
- Build: `__BE_BUILD__`
- Test: `__BE_TEST__`
- Format: `__BE_FORMAT__`
- Database: `__DB_START__`
- Migrations: `__MIGRATION__`
