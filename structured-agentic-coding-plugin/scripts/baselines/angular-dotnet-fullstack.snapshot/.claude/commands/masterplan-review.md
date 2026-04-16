# Masterplan Review

Review a completed masterplan against the current state of the repository **inline in this conversation**. Do NOT wrap yourself in an `Agent(...)` call. Delegate to leaf subagents only for isolated, context-heavy scans.

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
Glob: docs/masterplans/executed/*.md
```

Present the list and let the user pick:
> "Which masterplan do you want to review?"
> 1. `docs/masterplans/feature-a.md`
> 2. `docs/masterplans/executed/feature-b.md`

### Step 2: Run Reviewer Procedure (Inline)

Discover the reviewer procedure file:

```
Glob: .claude/agents/codebase/*-masterplan-reviewer.md
```

Read the full file. Ignore its `model:` / `effort:` frontmatter (legacy subagent config — does not apply inline). Follow its procedure **in this conversation**:

1. Parse the masterplan — extract tasks, decisions, success criteria
2. Verify task files exist (present/moved/missing)
3. Verify key implementation details via Grep/Read
4. Verify rule compliance via scan playbook patterns
5. Verify key decisions were followed
6. Verify success criteria (static checks only)
7. Update masterplan checkboxes for verified items
8. Run build/test verification
9. Generate the structured review report
10. Update anti-patterns if new recurring issues are found
11. Write the report to `docs/reports/`

**Delegate only heavy leaf work.** Most verification is direct Grep/Read in this conversation. Dispatch a subagent via the Agent tool only when a single step is genuinely context-heavy and isolated (e.g. a large scan playbook across many files). Orchestration never leaves the main chat.

**Paste, don't pass.** When delegating a scan, paste the scan playbook's check list and target file list into the subagent prompt — do not ask it to re-read the masterplan or playbook.

### Step 3: Present Results and Offer to Save

Display the review report to the user.

Then ask:
> "Save this review to `docs/reports/{feature-name}-masterplan-review.md`?"
- **Yes** → write the report to the file
- **No** → done

## Manual Invocation Patterns

- `review masterplan docs/masterplans/feature-a.md` → skip to Step 2 with the given path
- `review masterplan` → Step 1 (list and pick)
