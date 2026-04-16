---
name: masterplan-review
description: Review a completed masterplan against the repository — verify tasks were implemented, key decisions followed, success criteria met, rules not violated. Generates structured audit report with lessons learned.
---

# Masterplan Review

Review completed masterplans **inline in the main conversation**. Do NOT spawn the reviewer as a subagent — orchestration stays in the main chat; only isolated, context-heavy scans get delegated to leaf agents.

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

### Step 2: Discover Reviewer Procedure

```
Glob: .claude/agents/codebase/*-masterplan-reviewer.md
```

- **Found** → Read the full file. It contains the project-specific procedure with resolved build/test commands and scan playbook paths. Ignore its `model:` / `effort:` frontmatter (legacy subagent config — does not apply when running inline).
- **Not found** → Tell user: "No masterplan-reviewer procedure found. Run `/structured-agentic-coding` to scaffold your project first." Stop.

### Step 3: Execute Inline

Follow the procedure from the discovered file **in this conversation**. You ARE the reviewer — do not wrap yourself in an `Agent(...)` call.

The procedure covers: parse masterplan → verify task files exist → verify key implementation details (Grep/Read) → verify rule compliance via scan playbook patterns → verify key decisions followed → verify success criteria (static checks only) → update masterplan checkboxes → run build/test verification → generate structured review report → update anti-patterns if new recurring issues found → write report to `docs/reports/`.

**Delegate only heavy leaf work.** Most verification is direct Grep/Read in the main chat. Dispatch a subagent via the Agent tool only when a single step is genuinely context-heavy and isolated — e.g. running a large scan playbook across many files. Orchestration never leaves the main chat.

**Paste, don't pass.** When delegating a scan, paste the scan playbook's check list and the target file list directly into the subagent prompt. Do not ask it to re-read the masterplan or the playbook file.

### Step 4: Present Results

Display the review report to the user.

Ask:
> "Review report saved to `docs/reports/{feature-name}-review.md`. Any items you want to investigate further?"
