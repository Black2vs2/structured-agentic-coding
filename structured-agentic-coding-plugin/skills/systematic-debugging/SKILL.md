---
name: systematic-debugging
description: Disciplined four-phase debugging — root cause investigation, pattern analysis, hypothesis testing, then implementation. Prevents symptom-chasing and random-fix churn. Use for any bug beyond a trivial typo.
---

# Systematic Debugging

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.** Symptom fixes without understanding the underlying cause waste time and create new problems.

Four mandatory phases. Do them in order. Do not skip.

## Phase 1: Root Cause Investigation

Goal: understand the failure mechanism, not just its surface.

1. **Read the error completely.** Full stack trace, error code, exit code, the ~20 lines before and after the apparent failure in the log — all of it.
2. **Reproduce reliably.** You must be able to trigger the bug on demand. If you can't reproduce, STOP and build a minimal reproducer before continuing. "Intermittent" usually means "conditions not yet identified", not "random".
3. **Check recent changes:**
   ```bash
   git log --oneline -20
   git log -p {suspect_file}
   ```
   Did the bug appear after a specific commit? `git bisect` when non-obvious.
4. **Instrument at boundaries** in multi-component systems. Add logging at input/output of each component, data transforms, boundary crossings (API call, DB query, message send). Watch where the value you expect diverges from what's actually flowing.
5. **Trace data flow backward** from the point of failure until you find where a bad value originates. The first place the value is wrong is the cause; everything downstream is a symptom.

**Use graph tools** (`mcp__code-graph__*` if available in this project) for structural queries — "where is X called from", "what implements Y" — to avoid blind grepping.

**Output of Phase 1:** one specific sentence — "The bug is that `X` returns null when `Y` is empty, which happens because `Z` doesn't initialize it in the new flow."

Do not proceed to Phase 2 until you have this sentence.

## Phase 2: Pattern Analysis

Goal: leverage what already works.

1. **Find similar working code** — grep for the same pattern elsewhere in the codebase that works correctly.
2. **Read the working reference end-to-end.** Do not skim. You must understand *why* the working version works.
3. **Catalog every difference** between the working and broken versions: imports, call order, arguments, lifecycle, configuration, dependencies. Every single difference.
4. **Understand the dependencies** and assumptions of both. One of the differences is the cause.

**Output of Phase 2:** a specific list of differences, ranked by causal plausibility.

## Phase 3: Hypothesis and Testing

Goal: scientific method. Prove, don't guess.

1. **Write the hypothesis down** in one sentence: "If I change X, Y will happen, because Z."
2. **Minimal change** to test it — ideally single-line or single-character. Not a refactor. Not a cleanup.
3. **Run the reproducer.** Verify the hypothesis was correct before moving on.
4. **If wrong, acknowledge the gap** — don't paper over with "let me try something else". Return to Phase 1 or Phase 2 with the new information.

**Three-strikes rule:** if three hypotheses fail in a row → STOP. Your mental model is wrong. Question assumptions (is the bug where you think it is? are you testing what you think you're testing?). The answer is often architectural, not in the code you are looking at.

## Phase 4: Implementation

Goal: fix root cause, lock in with a test, don't regress.

1. **Write a failing test first** — a regression test that fails because of the bug. If you can't write one, you don't yet understand the bug (return to Phase 1).
2. **Single change** that makes the test pass.
3. **Verify via verification-before-completion skill:** run the failing test → green; run the full affected test suite → no new failures.
4. **Verify the original reproducer** no longer triggers.
5. **Commit with a root-cause message**, not a symptom message:
   - Good: `fix(auth): init session cache before first request (was null on cold start)`
   - Bad: `fix: session bug`

## Red Flags

Thinking patterns that mean you are skipping the process:
- "Let me just try adding X and see if it helps"
- "I'll fix the immediate issue and investigate later"
- "Maybe this works" (as the fix itself)
- Multiple simultaneous changes without a single-variable test
- Continuing to try fixes after 3 failed attempts
- "I think I see the issue" without having reproduced the bug
- Fixing the error message instead of the cause ("let's catch it and log")

If you catch yourself in any of these → reset to Phase 1.

## After the Fix

1. **Update `.claude/anti-patterns.md`** if the bug revealed a systemic trap others could fall into. Include: what happened, why it was easy to miss, the check/rule that would have caught it.
2. **If the bug originated from a masterplan task**, note it in the masterplan's report so the reviewer can update rules and patterns.

## Why

Systematic debugging typically takes 15–30 minutes and lands a fix on the first real attempt. Random-fix debugging takes 2–3 hours and lands roughly 40% of the time. The discipline is slower at the start and much faster overall.
