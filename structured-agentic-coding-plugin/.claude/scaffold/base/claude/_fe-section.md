
## Frontend

Rules: `.claude/rules/fe-rules.json` — enforced by frontend code review agents.

Agent directories:
- `__FE_DIR__/.claude/agents/` — Frontend agents (dev, reviewer, fixer)
- `__FE_DIR__/.claude/agents/fe-scans/` — Frontend scan playbooks

Commands:
- Dev: `__FE_SERVE__`
- Build: `__FE_BUILD__`
- Test: `__FE_TEST__`
- Format: `__FE_FORMAT__`
- Lint: `__FE_LINT__`
- E2E tests: `__E2E_CMD__`
