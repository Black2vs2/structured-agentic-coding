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

### Surrendering too quickly
**Pattern:** Agent marks a task as blocked or escalates after one failed attempt.
**Rule:** Before marking anything as blocked, try at least 2 different approaches. For code issues, try a different implementation path. For test failures, try adjusting the approach. Only then escalate with: what was tried, why it failed, suggested alternatives.
**Why:** Most tasks have multiple valid solutions. The first approach failing doesn't mean the task is impossible.

### Critical thinking deficit
**Pattern:** Agent blindly follows instructions without questioning assumptions or proposing alternatives.
**Rule:** Verify assumptions before implementing. If you see a better approach than what's prescribed, propose it (but don't implement without approval). Report problems early — don't wait until the end of a phase to mention a fundamental issue you noticed at the start. Balance critical thinking with execution speed — don't over-analyze to the point of paralysis.

### Skipping tests silently
**Pattern:** Agent reports "tests pass" but actually skipped failing or difficult tests.
**Rule:** SKIP = FAIL. Any test report with skipped tests is treated as a failure. Tests must either run and pass, or explicitly fail with a reason. Never skip a test to make a green report.

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

### RACE-001: Concurrent file writes
**Pattern:** Two parallel agents write to the same file simultaneously, causing merge conflicts or data loss.
**Rule:** No two agents dispatched in the same batch may have overlapping files in their `Files:` lists. The executor's dependency analysis already checks this — if overlap exists, tasks must run sequentially, never in parallel. If dispatching parallel worktree agents, verify file disjointness before dispatch.
**Why:** Git merge conflicts from concurrent edits waste more time than sequential execution would have.
