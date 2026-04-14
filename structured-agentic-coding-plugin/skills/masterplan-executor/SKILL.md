---
name: masterplan-executor
description: Execute a masterplan file — parse phases and tasks, dispatch dev agents per task with rules injection, review incrementally, fix issues with circuit breaker, commit per phase. Resume interrupted masterplans from last unchecked task.
---

# Masterplan Executor

Execute masterplan files by dispatching dev agents for implementation and verifying quality at every step. This skill spawns the executor as an Agent because the execution flow is automated and long-running.

## Procedure

### Step 1: Resolve Masterplan Path

If a masterplan path was provided as args, use it directly.

Otherwise, find available masterplans:

```
Glob: docs/masterplans/*.md
```

- If one masterplan exists → confirm with user and use it
- If multiple exist → list them and ask user to pick
- If none exist → tell user: "No masterplans found. Create one with `/masterplan architect`"

### Step 2: Discover Executor Agent

```
Glob: .claude/agents/codebase/*-masterplan-executor.md
```

- **Found** → Read the full agent definition file. It contains the project-specific procedure with resolved build commands, directory paths, agent discovery patterns, and rules injection logic.
- **Not found** → Tell user: "No masterplan-executor agent found. Run `/structured-agentic-coding` to scaffold your project first." Stop.

### Step 3: Spawn Executor Agent

Spawn the executor as an Agent. The prompt must include:
1. The agent definition content (or path to read)
2. The masterplan file path
3. Instruction to follow the agent definition's procedure exactly

```
Agent(
  subagent_type="general-purpose",
  model="opus",
  prompt="You are the masterplan-executor agent.

  Read and follow the agent definition at {discovered_agent_path} exactly.

  Execute the masterplan at: {masterplan_path}

  The agent definition contains your full procedure:
  1. Parse the masterplan file — find first unchecked task to resume from
  2. Pre-flight validation (protected paths, dependencies, UI decisions)
  3. Execute phases sequentially, tasks in parallel batches where possible
  4. Dispatch dev agents per task scope (be/fe/mixed/openapi-regen/e2e)
  5. Run targeted code reviews after each task
  6. Fix blocking issues (max 3 iterations with circuit breaker)
  7. Purpose validation — verify acceptance criteria before marking complete
  8. Build verify and commit after each phase
  9. Finalize — regenerate manifest, run masterplan review, generate report

  Report progress as you complete each phase.
  Escalate to user on failures — do NOT skip or guess."
)
```

### Step 4: Report Results

When the executor agent completes, relay its output to the user:
- Completion report path
- Summary of phases/tasks completed
- Any open issues or escalations
- Test checklist location
