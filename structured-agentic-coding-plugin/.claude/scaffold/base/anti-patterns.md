# Anti-Patterns

Known failure modes from past executions. Read by:
- **Architect** — for task design (avoid repeating mistakes)
- **Executor** — for prompt injection (warn dev agents)
- **Reviewer** — for regression detection

---

## General — Task Discipline

- Don't modify files outside task's `Files:` list — STOP and report if other files need changes
- Don't add features beyond task description — scope creep causes regressions
- Always run build verification after changes
- Stop and report if task seems wrong or conflicts with existing code
- Don't skip running tests
- Read existing file patterns before creating new files — follow them exactly

## Frontend — Patterns

- Read the closest existing page/component and follow its structure exactly
- No new architectural patterns (base classes, store features, layout systems) without explicit masterplan approval
- Don't modify generated/auto-generated files — fix the source instead

## Backend — Patterns

- All business logic through the designated handler/service pattern — not in controllers
- Don't bypass audit or validation interceptors with raw SQL or direct DB access
- Don't return full DTOs from create operations — return identifiers only

## Process Management

- Always use health check polling when starting services (never `sleep N`)
- Always stop backend services when done (even on failure)
- Always build before starting services
