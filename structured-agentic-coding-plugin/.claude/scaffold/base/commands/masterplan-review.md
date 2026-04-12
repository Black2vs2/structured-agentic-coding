# Masterplan Review

Review a completed masterplan against the current state of the repository. Verifies that planned tasks were implemented, key decisions were followed, and success criteria are met.

## When to Trigger

- User says "review masterplan", "check masterplan", "verify masterplan"
- User wants to audit whether a past feature was fully implemented
- User wants to compare planned vs actual implementation

## Procedure

### Step 1: Find the Masterplan

If the user specified a path, use it directly.

Otherwise, list available masterplans and ask which one to review:

```
Glob: docs/masterplans/*.md
```

Present the list and let the user pick:
> "Which masterplan do you want to review?"
> 1. `docs/masterplans/feature-a.md`
> 2. `docs/masterplans/feature-b.md`
> ...

### Step 2: Invoke Reviewer Agent

Discover the masterplan-reviewer agent:

```
Glob: .claude/agents/codebase/*-masterplan-reviewer.md
```

Read the first 3 lines to confirm its role, then spawn it:

```
Agent(
  subagent_type="general-purpose",
  prompt="You are the masterplan-reviewer agent. Read and follow the agent definition at {discovered_agent_path} exactly.

  Review the masterplan at: {masterplan_path}
  Today's date: {current_date}

  Follow the Procedure in the agent definition:
  1. Parse the masterplan file — extract tasks, decisions, success criteria
  2. Verify task files exist
  3. Verify key implementation details via grep/read
  4. Verify key decisions were followed
  5. Verify success criteria (static checks only)
  6. Run build verification
  7. Generate the structured review report

  Return the full report as your final output."
)
```

### Step 3: Present Results and Offer to Save

Display the reviewer's report to the user.

Then ask:
> "Save this review to `docs/reports/{feature-name}-masterplan-review.md`?"

- **Yes** → write the report to the file
- **No** → done

### Manual Invocation Patterns

- `review masterplan docs/masterplans/feature-a.md` → skip to Step 2 with the given path
- `review masterplan` → Step 1 (list and pick)
