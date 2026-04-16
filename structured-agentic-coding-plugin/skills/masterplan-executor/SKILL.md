---
name: masterplan-executor
description: Execute a masterplan file — parse phases and tasks, dispatch dev agents per task with rules injection, review incrementally, fix issues with circuit breaker, commit per phase. Resume interrupted masterplans from last unchecked task.
---

# Masterplan Executor

Execute masterplan files **inline in the main conversation**. Do NOT spawn the executor as a subagent — nested dispatch breaks and the main chat gets resumed from transcript on every follow-up (token burn). The main chat stays in the driver seat and dispatches dev/review/fix agents directly as leaves.

## Procedure

### Step 1: Resolve Masterplan Path

If a masterplan path was provided as args, use it directly.

Otherwise, find available masterplans:

```
Glob: docs/masterplans/*.md
```

- If one masterplan exists → confirm with user and use it
- If multiple exist → list them and ask the user to pick
- If none exist → tell user: "No masterplans found. Create one with `/masterplan architect`" and stop.

### Step 2: Discover Executor Procedure

```
Glob: .claude/agents/codebase/*-masterplan-executor.md
```

- **Found** → Read the full file. It contains the project-specific procedure with resolved build commands, directory paths, agent discovery patterns, and rules injection logic. Ignore its `model:` / `effort:` frontmatter (legacy subagent config — does not apply when running inline).
- **Not found** → Tell user: "No masterplan-executor procedure found. Run `/structured-agentic-coding` to scaffold your project first." Stop.

### Step 3: Execute Inline

Follow the procedure from the discovered file **in this conversation**. You ARE the executor — do not wrap yourself in an `Agent(...)` call.

The procedure covers: parse masterplan → pre-flight validation → execute phases sequentially (tasks in parallel batches where possible) → dispatch dev agents per task scope → targeted review → fix loop with circuit breaker → purpose validation → build verify → commit → finalize.

**Leaf dispatch only.** When the procedure says "dispatch dev/review/fix agent", use the Agent tool from this conversation. Those agents must be leaves — they implement/review/fix a single task and return. They do not orchestrate further phases.

**Paste task text, don't pass file paths.** Extract the task's full text (description, Files, Details, Accept, injected rules, anti-patterns) from the masterplan and paste it directly into the dispatched agent's prompt. Do NOT ask the subagent to re-read the masterplan file — this keeps its context minimal and avoids transcript-resume pitfalls.

**Track progress with TaskCreate.** Create one task per phase (or per task for large phases) and update status as you go. This makes resume trivial if the conversation is interrupted: on re-entry, re-read the masterplan, find the first unchecked `- [ ]` line, and continue from there.

**Escalate, don't guess.** On failures (circuit breaker tripped, build failing after 2 attempts, unexpected state), STOP and report to the user. Do not retry beyond the limits set in the procedure.

### Step 4: Report Results

After the procedure completes, summarize for the user:
- Completion report path (`docs/reports/{feature-name}-masterplan-report.md`)
- Phases/tasks completed vs total
- Any open issues or escalations
- Test checklist location (appended to the masterplan file)
