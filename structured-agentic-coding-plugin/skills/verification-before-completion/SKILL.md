---
name: verification-before-completion
description: Enforce evidence-before-completion. Before claiming a task, build, test, or fix is done, run the verifying command, read the actual output, and cite it. Prevents "should work" / "probably passes" failure modes. Use when about to say done/working/fixed/passing, about to relay an agent's self-report, claiming tests pass, or claiming a bug is resolved.
---

# Verification Before Completion

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.** You cannot assert that work passes without running the verification command and examining its actual output.

Use this skill at every claim of completion: task done, build passing, tests green, bug fixed, requirement met, agent-delegated work returned successful.

## The Gate Function

Before stating "done" / "working" / "fixed" / "passing":

1. **Identify the command** that would prove the claim. Examples:
   - "Build passes" → the project's build command
   - "Tests pass" → the project's test command (scoped to affected files/tests)
   - "Bug fixed" → the original reproducer (script, curl, UI step)
   - "Requirement met" → the concrete criterion from the task (accept list)
2. **Execute it freshly** — do not reuse output from earlier in the conversation or from an agent's self-report.
3. **Read the full output and exit code** — not just the summary line.
4. **Check that the output supports the specific claim** — not just "it didn't crash".
5. **Cite the evidence** when claiming: `Tests pass (12/12 in auth.spec.ts, exit 0)`.

Only after step 5 may you say it is done.

## Red Flags in Your Own Output

If you catch yourself writing any of these, STOP and run the verification first:
- "should work"
- "probably passes"
- "looks good" / "looks correct"
- "Done!" / "Perfect!" (before citing evidence)
- "The agent reported it was successful" (without independent check)
- "I believe this fixes it"

Confidence ≠ evidence. The user's trust depends on honesty about what you actually verified vs. what you assumed.

## When Agents Report Back

A delegated subagent saying "done" is NOT verification. Re-run the relevant build/test/repro yourself before relaying "done" to the user. The subagent may have:
- Claimed success without running the command
- Run a narrower scope than claimed
- Misread its own output

Trust but verify.

## Integration with Masterplan

The `structured-agentic-coding:masterplan-executor` Purpose Validation step (2e) is an instance of this skill: re-read the task's `Accept:` criteria, run the evidence command for each, then mark complete. The phase-verify step (2f) is another instance: build + test are the evidence commands for the phase.

When the executor dispatches a leaf dev agent and the agent reports back, the executor must itself verify — not relay the agent's self-report as completion.

## Scope

Applies to all completion claims — direct ("done"), implied ("moving on to X"), or paraphrased. Applies equally to code, docs, configuration, and infrastructure changes.

## Why

Unverified completion claims are the single largest source of broken trust between user and assistant: they ship broken code, require rework, and teach the user to distrust every claim. Running the command takes seconds. The alternative costs hours.
