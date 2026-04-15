# Masterplan Orchestrator

You orchestrate the masterplan lifecycle: detect multi-step feature work, invoke the architect for design, and hand off to the executor for implementation.

## When to Trigger

This skill applies when the user's request implies multi-step feature work:
- "Add [feature]", "Build [feature]", "Implement [feature]"
- Work that would span multiple files across backend and frontend
- User explicitly mentions "masterplan" or "plan for"
- Changes requiring new entities, handlers, controllers, AND UI components

This skill does NOT apply to:
- Single-file changes or bug fixes
- Pure refactoring within one layer
- Questions or research requests
- Running existing commands

## Procedure

### Step 1: Check for Existing Masterplan

Search for an existing masterplan that matches the requested feature:

```
Glob: docs/masterplans/*.md
```

If a matching masterplan exists, read it and check for unchecked `- [ ]` tasks.

- If incomplete tasks exist, ask the user:
  > "Found existing masterplan at `{path}` with {N} tasks remaining. Resume execution?"
  - **Yes** → skip to Step 3 (executor)
  - **No** → proceed to Step 2 (architect)

- If all tasks are checked, inform the user:
  > "Masterplan at `{path}` is already complete."
  Ask if they want to create a new one.

### Step 2: Invoke Architect

Discover the masterplan-architect agent:

```
Glob: .claude/agents/codebase/*-masterplan-architect.md
```

Read the first 3 lines to confirm its role, then spawn it:

```
Agent(
  subagent_type="general-purpose",
  prompt="You are the masterplan-architect agent. Read and follow the agent definition at {discovered_agent_path} exactly.

  The user wants to: {user's original request}

  Follow the Procedure in the agent definition:
  1. Orient — use graph tools to understand current structure
  2. Clarify — ask the user 5-8 questions (one at a time, prefer multiple choice)
  3. Design — produce the masterplan in the required format
  4. Present — show sections for approval
  5. Write — save to docs/masterplans/<feature-name>.md

  Return the masterplan file path as your final output."
)
```

Wait for the architect to complete. It will return the masterplan path.

### Step 3: Confirm Execution

Ask the user:
> "Masterplan written to `{path}`. Execute now?"

- **Yes** → proceed to Step 4
- **No** → done. Tell user: "You can execute later with: `execute masterplan {path}`"

### Step 4: Invoke Executor

Discover the masterplan-executor agent:

```
Glob: .claude/agents/codebase/*-masterplan-executor.md
```

Read the first 3 lines to confirm its role, then spawn it:

```
Agent(
  subagent_type="general-purpose",
  prompt="You are the masterplan-executor agent. Read and follow the agent definition at {discovered_agent_path} exactly.

  Execute the masterplan at: {masterplan_path}

  Follow the Procedure in the agent definition:
  1. Parse the masterplan file
  2. Execute phases sequentially, tasks in parallel batches where possible
  3. Run lightweight reviews after each task
  4. Fix blocking issues (max 3 iterations)
  5. Build verify and commit after each phase
  6. Escalate to user on failures

  Report progress as you complete each phase."
)
```

### Manual Invocation Patterns

- User says "execute masterplan {path}" → skip to Step 3 with the given path
- User says "create masterplan for X" → skip to Step 2
- User says "resume masterplan" → find the most recent `docs/masterplans/*.md` with unchecked tasks, confirm with user, then Step 4
- User says "review masterplan" → delegate to `/masterplan-review` command instead
