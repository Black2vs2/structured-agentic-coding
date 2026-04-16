# Masterplan Orchestrator

You orchestrate the masterplan lifecycle **inline in this conversation**: detect multi-step feature work, run the architect procedure for design, and run the executor procedure for implementation. Do NOT wrap yourself in an `Agent(...)` call — the main chat stays in the driver seat end-to-end. Subagents are dispatched only as leaves (per-task dev/review/fix work).

## When to Trigger

This applies when the user's request implies multi-step feature work:
- "Add [feature]", "Build [feature]", "Implement [feature]"
- Work that would span multiple files across backend and frontend
- User explicitly mentions "masterplan" or "plan for"
- Changes requiring new entities, handlers, controllers, AND UI components

Does NOT apply to:
- Single-file changes or bug fixes
- Pure refactoring within one layer
- Questions or research requests
- Running existing commands

## Procedure

### Step 1: Check for Existing Masterplan

```
Glob: docs/masterplans/*.md
```

If a matching masterplan exists, read it and check for unchecked `- [ ]` tasks.

- If incomplete tasks exist, ask:
  > "Found existing masterplan at `{path}` with {N} tasks remaining. Resume execution?"
  - **Yes** → skip to Step 3 (executor)
  - **No** → proceed to Step 2 (architect)
- If all tasks are checked:
  > "Masterplan at `{path}` is already complete."
  Ask if they want to create a new one.

### Step 2: Run Architect Procedure (Inline)

Discover the architect procedure file:

```
Glob: .claude/agents/codebase/*-masterplan-architect.md
```

Read the full file. Ignore its `model:` / `effort:` frontmatter (legacy subagent config — does not apply inline). Follow its procedure **in this conversation**:

1. Orient — use graph tools to understand current structure
2. Clarify — ask 5-8 questions (one at a time, prefer multiple choice)
3. Design — produce the masterplan in the required format
4. Self-grill — interrogate your own plan
5. Present — show sections for approval
6. User-grill — walk user through the decision tree
7. Write — save to `docs/masterplans/<feature-name>.md`

Output the masterplan path at the end.

### Step 3: Confirm Execution

Ask:
> "Masterplan written to `{path}`. Execute now?"

- **Yes** → proceed to Step 4
- **No** → done. Tell user: "Execute later with `/masterplan execute {path}`"

### Step 4: Run Executor Procedure (Inline)

Discover the executor procedure file:

```
Glob: .claude/agents/codebase/*-masterplan-executor.md
```

Read the full file. Ignore its `model:` / `effort:` frontmatter. Follow its procedure **in this conversation**:

1. Parse the masterplan — find the first unchecked task (resume point)
2. Pre-flight validation (protected paths, dependencies, UI decisions)
3. Execute phases sequentially, tasks in parallel batches where possible
4. Dispatch per-task **leaf** agents via the Agent tool (dev/reviewer/fixer)
5. Targeted review + fix loop with circuit breaker
6. Purpose validation against acceptance criteria
7. Build verify + commit per phase
8. Finalize — regenerate manifest, run review, generate report

**Leaf dispatch rules** (apply to every `Agent(...)` call you make):
- The dispatched agent implements/reviews/fixes a single scoped unit and returns. It does NOT orchestrate further phases.
- **Paste task text, don't pass the masterplan path.** Extract the task's full text (description, Files, Details, Accept, injected rules, anti-patterns) from the masterplan and put it directly in the prompt. Subagents should not re-read the masterplan file — this keeps their context minimal and sidesteps transcript-resume token burn.

Use `TaskCreate` to track phases as they progress — one task per phase, updated as you go. On interrupt, resume is trivial: re-read the masterplan and continue from the first unchecked `- [ ]`.

Escalate to the user on failures. Do NOT skip or guess.

## Manual Invocation Patterns

- User says "execute masterplan {path}" → skip to Step 3 with the given path
- User says "create masterplan for X" → skip to Step 2
- User says "resume masterplan" → find the most recent `docs/masterplans/*.md` with unchecked tasks, confirm, then Step 4
- User says "review masterplan" → delegate to `/masterplan-review` command
