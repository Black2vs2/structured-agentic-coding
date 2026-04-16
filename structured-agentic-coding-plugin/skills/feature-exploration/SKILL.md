---
name: feature-exploration
description: End-to-end autonomous feature exploration — one scoping brief drives deep-research (web) and codebase-pattern-match (local repo), then cross-references external evidence against local patterns to produce a proposal with 2-3 implementation options and a recommended pick. Hands off to masterplan-architect. Use when the user says explore a feature, research and plan, propose implementations, investigate how to add X, or asks for a researched proposal before committing to a plan.
---

# Feature Exploration

Produce a researched and locally-grounded feature proposal by combining external evidence (how the industry solves X) with internal context (how our codebase already solves similar things). Runs inline in the main conversation.

Announce at start: "Running feature-exploration on: `{feature}`. This will take several minutes."

## Procedure

### Step 1: Unified Scoping Brief

Produce one brief that serves both sub-skills. Write `docs/research/{feature-slug}.brief.md`:

```markdown
# Feature Brief: {feature}

**What we're building:** One sentence.
**Why:** Motivation / the decision this feeds.
**External research scope:**
- Industry patterns to investigate: ...
- Companies / tools of interest: ... (optional user hint)
- Explicit disconfirming angles: ... (what to argue AGAINST)
**Local scope:**
- Similar concerns already in this codebase: {initial guess, will be validated}
- Directories / modules likely involved: ...
**Constraints:**
- Tech stack, language, frameworks (read `CLAUDE.md` if available)
- Protected paths from existing masterplans
**Success criteria:**
- {2-3 concrete things the final proposal must contain}
```

Show to user. Wait for an explicit `go`.

### Step 2: Check Size First

If the feature is small enough that full exploration would be overkill (e.g. "add a tooltip", "rename a column", a bug fix) — ask the user:
> "This looks narrow. Full feature-exploration burns ~10× a normal chat turn. Use `structured-agentic-coding:masterplan-architect` directly instead?"

Only proceed past this gate if the feature genuinely spans unknowns.

### Step 3: Run the Two Sub-Skills

Sequentially (each internally dispatches parallel leaves — total wall-clock remains acceptable and avoids nested-subagent risks):

1. Invoke `structured-agentic-coding:deep-research` via the Skill tool. Pass the feature as topic. Forward any `effort=lite|balanced|max` override from this skill's args. Wait for it to write `docs/research/{feature-slug}.md`.
2. Invoke `structured-agentic-coding:codebase-pattern-match` via the Skill tool with the same topic. Wait for it to write `docs/research/{feature-slug}.patterns.md`.

**Fail-fast rules:**
- If deep-research reports "could not find Tier 1/2 evidence" → STOP and escalate. Do not build a proposal on Tier 3 or speculation.
- If codebase-pattern-match reports "topic doesn't map to this codebase" → the feature is likely net-new. Continue to Step 4 but mark every cross-reference as "Introduce (no local analog)".

### Step 4: Cross-Reference

Read both reports. For every key finding in the research report, find the local analog in the patterns report. Examples:
- "Netflix uses circuit breakers with Hystrix" → "We have retry logic at `src/http/retry.ts:15`. Extending that module is more consistent than introducing Hystrix."
- "OAuth spec recommends PKCE for public clients" → "Our auth layer at `src/auth/oauth.ts` does not implement PKCE. Adding it fits the existing `AuthStrategy` abstraction."

For each cross-reference, decide:
- **Extend** — local analog is reusable and should be generalized
- **Replace** — local analog is inferior and should be rewritten using the external pattern
- **Introduce** — no local analog; this is net-new code

### Step 5: Produce Feature Proposal

Write `docs/research/{feature-slug}.proposal.md`:

```markdown
# Feature Proposal: {feature}

**Brief:** `docs/research/{feature-slug}.brief.md`
**External research:** `docs/research/{feature-slug}.md`
**Local patterns:** `docs/research/{feature-slug}.patterns.md`
**Generated:** {ISO timestamp}

## Executive Summary
{3-5 sentences. The feature, 2-3 implementation options at high level, recommended pick.}

## External Evidence → Local Fit
{For each industry practice relevant to the feature, show the local analog (if any) and the Extend / Replace / Introduce decision. Table or bulleted list.}

## Implementation Options

### Option A: {short name}
**Approach:** ...
**Strength:** ...
**Weakness:** ...
**Fit score (local conventions):** High / Medium / Low — why
**Rough effort:** S / M / L
**Exemplars to follow:** {file:line refs from patterns report}

### Option B: {short name}
(same structure)

### Option C: {short name} (optional — only if genuinely distinct)
(same structure)

## Recommended Pick
{One of A / B / C. Explicit reasoning: fit + effort + strategic value. If tied, say so and list the deciding question for the user.}

## Open Questions for Human
{What the proposal cannot resolve without human input — typically priority tradeoffs, strategic direction, external dependency choices.}

## Next Step
If the user agrees with a recommendation → hand off to `structured-agentic-coding:masterplan-architect` with this proposal file path as input. The architect's Clarify phase should start with the resolved proposal, not a blank slate.
```

### Step 6: Present and Hand Off

Short user-facing summary:
- Path to the full proposal
- The recommended option in 2-3 sentences
- Any Open Questions that need a human answer

Offer:
> "Ready to generate a masterplan from Option {X}? Invoke `structured-agentic-coding:masterplan-architect` with this proposal file?"

## Args

- `effort=lite|balanced|max` — forwarded to deep-research. Default: `balanced`.

## Integration

- Calls `structured-agentic-coding:deep-research` (Phase 1 of the research pipeline)
- Calls `structured-agentic-coding:codebase-pattern-match` (Phase 2)
- Hands off to `structured-agentic-coding:masterplan-architect` — which accepts the proposal file path as args and uses it as resolved context for its Clarify phase

## Budget

Full exploration at `balanced`: deep-research (~7× chat tokens) + codebase-pattern-match (~3×) + synthesis (~1×) ≈ **11× a normal chat turn**. At `max`: ≈ 20×. Use `lite` (~5×) for fast exploratory work.
