---
name: masterplan-review
description: Review a completed masterplan against the repository — verify tasks were implemented, key decisions followed, success criteria met, rules not violated. Generates structured audit report with lessons learned.
---

# Masterplan Review

Review completed masterplans against the current state of the repository. Spawns the reviewer as an Agent for automated verification.

## Procedure

### Step 1: Resolve Masterplan Path

If a masterplan path was provided as args, use it directly.

Otherwise, find available masterplans:

```
Glob: docs/masterplans/*.md
Glob: docs/masterplans/executed/*.md
```

Present the list and ask which one to review:
> "Which masterplan do you want to review?"
> 1. `docs/masterplans/feature-a.md`
> 2. `docs/masterplans/executed/feature-b.md`

### Step 2: Discover Reviewer Agent

```
Glob: .claude/agents/codebase/*-masterplan-reviewer.md
```

- **Found** → Read the full agent definition file. It contains the project-specific procedure with resolved build/test commands and scan playbook paths.
- **Not found** → Tell user: "No masterplan-reviewer agent found. Run `/structured-agentic-coding` to scaffold your project first." Stop.

### Step 3: Spawn Reviewer Agent

```
Agent(
  subagent_type="general-purpose",
  model="opus",
  prompt="You are the masterplan-reviewer agent.

  Read and follow the agent definition at {discovered_agent_path} exactly.

  Review the masterplan at: {masterplan_path}
  Today's date: {current_date}

  The agent definition contains your full procedure:
  1. Parse the masterplan — extract tasks, decisions, success criteria
  2. Verify task files exist (present/moved/missing)
  3. Verify key implementation details via grep/read
  4. Verify rule compliance using scan playbook patterns
  5. Verify key decisions were followed
  6. Verify success criteria (static checks only)
  7. Update masterplan checkboxes for verified items
  8. Run build and test verification
  9. Generate structured review report
  10. Update anti-patterns if new recurring issues found
  11. Write report to docs/reports/

  Return the full report as your final output."
)
```

### Step 4: Present Results

Display the reviewer's report to the user.

Ask:
> "Review report saved to `docs/reports/{feature-name}-review.md`. Any items you want to investigate further?"
