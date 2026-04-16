---
name: finishing-a-development-branch
description: Wrap up a development branch after implementation is complete — run final verification, format, offer merge / PR / keep / discard options, execute the chosen path cleanly. Pairs with masterplan-executor to produce the final PR. Use when the user says finish, wrap up, close out, ship, ready to merge, open a PR, done with this branch, or time to push.
---

# Finishing a Development Branch

Close out work on a feature/fix branch through a structured **verify → decide → execute** flow. Call this after implementation is done: end of a masterplan, end of a standalone feature, end of a bug-fix session.

Announce at start: "Running the finishing-a-development-branch skill to close out this branch."

## Procedure

### Step 1: Verify (Gate)

Invoke the **`structured-agentic-coding:verification-before-completion`** skill. Do NOT proceed past this step without passing evidence:

1. Run the full project test suite (BE + FE as applicable, from `.claude/` config or scaffolded commands)
2. Run the build (BE + FE as applicable)
3. Run formatters and confirm no diff remains
4. `git status` — working tree clean; no debris (stray `console.log`, temp files, `TODO` markers added during dev)

If any step fails → STOP, report, do not proceed to Step 2. User fixes, then re-enter at Step 1.

### Step 2: Determine Base Branch

```bash
git remote show origin | sed -n '/HEAD branch/s/.*: //p'
```

Fall back to `main`, then `master` if the command fails or the repo is offline. If the current branch was not forked from the detected base, confirm with the user.

### Step 3: Summarize What Changed

Gather context for commit/PR messages:
- `git log {base}..HEAD --oneline` — commits on this branch
- `git diff --stat {base}..HEAD` — files changed
- If a masterplan exists under `docs/masterplans/executed/{feature}.md` → read Goal, Scope, Key Decisions for the PR body
- If a report exists under `docs/reports/{feature}-masterplan-report.md` → read it for the Test Checklist

### Step 4: Present Four Options

Ask the user exactly:
> "Implementation verified. How do you want to close this out?
> 1. **Merge locally** into `{base}` (no push)
> 2. **Push and open PR** against `{base}` (recommended)
> 3. **Keep as-is** — branch stays, no action
> 4. **Discard** — delete the branch and all its work
>
> Reply with 1 / 2 / 3 / 4."

Do NOT default. Wait for the user's explicit choice.

### Step 5: Execute the Chosen Option

**Option 1 — Merge locally**
```bash
git checkout {base}
git pull --ff-only
git merge --no-ff {branch}
```
Confirm merge success. Do NOT push.

**Option 2 — Push and open PR**
```bash
git push -u origin {branch}
gh pr create --base {base} --title "<title>" --body "$(cat <<'EOF'
## Summary
<1-3 bullets derived from masterplan Goal or commit log>

## Changes
<files changed, grouped by area>

## Test plan
<test checklist from the masterplan report, or a derived one>
EOF
)"
```

PR title: derived from branch name or primary commit, under 70 chars. PR body template above — paste the test checklist from the masterplan report if present.

Output the PR URL.

**Option 3 — Keep as-is**
Report: "Branch `{branch}` preserved. {N} commits ahead of `{base}`. Resume later with this branch checked out."

**Option 4 — Discard**
Require an exact typed confirmation:
> "To discard, reply with exactly: `discard`
> This will permanently delete branch `{branch}` and all its commits. Irreversible."

If the user types anything other than exactly `discard` → abort and fall back to Option 3.
On confirmed discard:
```bash
git checkout {base}
git branch -D {branch}
# If a worktree is in use, also remove via the `structured-agentic-coding:using-git-worktrees` skill.
```

### Step 6: Report

Tell the user exactly what happened: commits merged, PR URL, branch preserved, or branch discarded. Include next steps if relevant (e.g., "PR awaits review at {URL}").

## Integration

- **`structured-agentic-coding:verification-before-completion`** — invoked at Step 1 as the gate
- **`structured-agentic-coding:masterplan-executor`** report — mined at Step 3 for PR description and test checklist
- **`structured-agentic-coding:using-git-worktrees`** (when implemented) — called at Step 5 for worktree cleanup

## Safeguards

- Never proceed past Step 1 with failing tests or a dirty tree
- Never delete a branch without exact `discard` confirmation
- Never force-push on Option 2 — `gh pr create` on a new branch does not need it. Only force-push if the user explicitly requests it after rebasing
- Never push to `{base}` directly
