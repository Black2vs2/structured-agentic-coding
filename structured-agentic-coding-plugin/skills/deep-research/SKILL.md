---
name: deep-research
description: Autonomous web deep-research — scoping brief → parallel search subagents with one forced disconfirming query → CitationAgent verification → synthesis report with tiered sources (Tier 1 official / Tier 2 vetted engineering blogs; Tier 3 SEO farms explicitly ignored). Use when the user says research, deep research, investigate, survey, find best practices, find out how X companies solve Y, or asks to gather information from the internet before planning.
---

# Deep Research

Produce a cited, synthesis-grade report on any topic by spawning parallel search subagents, verifying their citations, and mapping findings to explicit source tiers. Runs inline in the main conversation; dispatches leaf subagents only for isolated search/fetch work.

Announce at start: "Running the deep-research skill on: `{topic}`. Effort: `{lite|balanced|max}`."

## Procedure

### Step 1: Scoping Brief (Mandatory Gate)

Before spending tokens on search, produce a written brief and get user confirmation. This is the north-star document — kills scope drift.

Write `docs/research/{topic-slug}.brief.md`:

```markdown
# Research Brief: {topic}

**Question:** One sentence framing what we're actually answering.
**Motivation:** Why this research — what decision or feature does it feed?
**Scope:**
- In: {2-4 bullets of what we WILL investigate}
- Out: {2-4 bullets of what we will NOT investigate}
**Success criteria:** What does a useful answer look like? (list of concrete artefacts — e.g. "3 concrete implementation patterns with tradeoffs", "source list", "recommended default").
**Constraints:** Tech stack, language, existing patterns in THIS codebase that the answer must fit.
```

Show the brief to the user. Ask:
> "Is this the research you want? Edit anything or reply `go` to start."

Do NOT proceed without an explicit `go`. Modifications loop back through the user until they confirm.

### Step 2: Parse Effort Level

Parse `effort=X` from the skill args. Default: `balanced`.

| Effort | Parallel subagents | Recursion rounds | Wall-clock cap (per round) |
|---|---|---|---|
| `lite` | 2 | 1 | 90 s |
| `balanced` (default) | 3 | 2 | 2 min |
| `max` | 5 | 3 | 4 min |

These are hard ceilings. Do not exceed.

### Step 3: Round 1 — Plan Queries (Cheap Planner)

Use the **cheapest capable model** as the planner (Haiku if available, else the main model but with a terse prompt). Produce `N` queries where `N = parallel subagents count`:

- **N−1 positive queries** — cover distinct angles of the brief (avoid overlapping phrasings)
- **1 forced disconfirming query** — phrased to surface arguments *against* the dominant approach. Example: "arguments against using X for Y", "when X fails", "cases where X is the wrong tool"

Show the query list to the user briefly ("Searching: 1. … 2. … 3. (disconfirming)"). Do NOT pause for approval unless the brief was non-trivial.

### Step 4: Round 1 — Parallel Search Subagents

Dispatch `N` subagent leaves **in parallel** (single message, multiple Agent tool calls). Each subagent prompt must include:

1. The specific query it owns
2. The Source Tier policy (see "Source Tiers" section below) — pasted in full
3. Explicit output contract: return 3-6 findings in the exact format below
4. Wall-clock ceiling from the effort table
5. The instruction to use `WebSearch` to discover URLs and `WebFetch` to read them

Subagent output contract:
```markdown
## Finding {N}
**Claim:** One-sentence assertion.
**Source:** URL
**Tier:** 1 | 2   (if Tier 3, DISCARD — do not return)
**Evidence:** 1-3 direct quotes or specific data points from the source.
**Relevance:** Why this matters for the brief's question.
```

Subagents must NOT synthesise. They return raw findings only. The orchestrator (main chat) synthesises.

### Step 5: Gap Analysis (Before Round 2)

Main chat reads all Round 1 findings. Ask yourself:
- Which parts of the brief's Success Criteria are covered? Which aren't?
- Are all findings concentrated on one viewpoint? (echo chamber smell)
- Did the disconfirming query return actual counter-evidence, or did it fail to dig up anything? (if the latter, the dominant view may genuinely be dominant, or the query was too weak)

If `balanced` or `max` and uncovered Success Criteria remain → Round 2 with focused follow-up queries on the gaps. If `lite` or coverage is complete → skip to Step 6.

### Step 6: CitationAgent Verification Pass

Dispatch ONE subagent leaf (in parallel with nothing else) with role **CitationAgent**. Its job:
- Receive the full list of findings from Rounds 1+2
- For each finding, fetch the source URL via WebFetch
- Verify the Evidence quotes actually appear in the source and support the Claim
- Return per-finding verdict: `VERIFIED` / `WEAK` (quote present but doesn't support claim) / `UNSUPPORTED` (quote not found or source unrelated)
- **Explicitly required** — baseline measurement across LLM search products shows only ~51.5% of citations are genuinely supported

Findings marked `UNSUPPORTED` → **dropped**. Findings marked `WEAK` → kept but flagged in the final report.

### Step 7: Synthesis (Expensive Synthesizer)

Use the strongest available model (main chat = Opus/Sonnet 4.6) for this step. Produce the final report at `docs/research/{topic-slug}.md`:

```markdown
# Research Report: {topic}

**Brief:** docs/research/{topic-slug}.brief.md
**Generated:** {ISO-8601 timestamp}
**Effort:** {lite|balanced|max}
**Rounds executed:** {1|2|3}
**Findings kept after CitationAgent:** {N} (Tier 1: {x}, Tier 2: {y})

## Executive Summary
{3-5 sentences. The answer to the brief's Question, stated plainly.}

## Key Findings
{For each finding or cluster of findings:}
### {Short title}
{1-2 paragraph synthesis. Every factual claim MUST carry an inline citation in the form `[1]`, `[2]` referring to the Sources list at the bottom. Weak-verified findings carry `[3 — partial support]`.}

## Tradeoffs / Disconfirming Evidence
{Dedicated section for the disconfirming-query findings and any tension between sources. Do NOT flatten tradeoffs — show them.}

## Recommendations
{Concrete, actionable options mapped to the brief's Constraints. Max 3 options, each with: approach, strength, weakness, best-fit condition.}

## Open Questions
{What the research did NOT answer. Be honest — don't pretend gaps aren't there.}

## Sources
{Numbered list of cited URLs with tier annotation:
[1] Tier 1 — Official React docs — react.dev/learn/xxx
[2] Tier 2 — Stripe Engineering — stripe.com/blog/xxx
[3] Tier 2 — Netflix TechBlog — netflixtechblog.com/xxx (partial support)
}
```

### Step 8: Report

Tell the user:
- Report path: `docs/research/{topic-slug}.md`
- Effort used, rounds executed, findings kept
- Any open questions flagged for follow-up
- Suggest next step if the research feeds a feature plan: "Hand off to `structured-agentic-coding:masterplan-architect` with this report as input?"

## Source Tiers

**Tier 1 — Always prefer:**
- Official documentation (docs.*, *.dev, language/framework reference sites, AWS/GCP/Azure official docs)
- IETF RFCs, W3C specs, language standards
- Peer-reviewed papers (arxiv.org, ACM, IEEE, USENIX)
- Vendor security advisories, CVE databases
- GitHub repositories with ≥1000 stars for source-of-truth code, issues, discussions
- Official release notes, changelogs, RFC/proposal documents for the tool in question

**Tier 2 — Use for "how it actually works in production":**
Engineering blogs from companies with publicly credible engineering practice. Explicit whitelist (not exhaustive, but use as a reference — if the blog is from a comparable engineering org, count it as Tier 2):
- stripe.com/blog, netflixtechblog.com, eng.uber.com, shopify.engineering, airbnb.io, dropbox.tech, github.blog/engineering, about.gitlab.com/blog/engineering, blog.cloudflare.com, aws.amazon.com/blogs/architecture, cloud.google.com/blog, devblogs.microsoft.com, engineering.fb.com, engineering.linkedin.com, medium.com/pinterest-engineering, blog.twitter.com/engineering, engineering.atspotify.com, codeascraft.com (Etsy), engineering.zalando.com, martinfowler.com, highscalability.com, infoq.com (articles, not user-submitted)

**Tier 3 — IGNORE. Do not cite, do not read beyond a title skim:**
- SEO content farms (hackernoon.com aggregators, dev.to majority, medium.com non-engineering-org posts, tutorialspoint, geeksforgeeks for advanced topics, w3schools)
- AI-generated content mills
- "Top 10 X for Y" listicles unless from Tier 1/2 orgs
- Sponsored content, "powered by X" marketing pages
- Personal blogs without identifiable author credentials on the topic
- Stack Overflow answers with <10 upvotes or no accepted marker (use only as pointer to official docs)
- Reddit/HN threads (use only to discover Tier 1/2 links, never cite directly)

**When Tier 3 is the only result:** treat it as a signal the query was wrong. Return to Step 3 and reformulate. Do NOT cite Tier 3. If after reformulation still only Tier 3 surfaces → report to user as an open question ("could not find Tier 1/2 evidence for: …").

## Red Flags During Execution

Stop and reassess if any of these occur:
- All findings from one round agree perfectly (echo chamber — add a second disconfirming query)
- The disconfirming query returned *zero* useful results across rounds (query was too weak or too strong — reformulate)
- A subagent returns findings without URLs or with URLs that don't fetch (discard the finding, log it)
- CitationAgent marks >30% of findings `UNSUPPORTED` (subagent methodology is broken — escalate to user)
- Wall-clock budget hit before returning useful findings (raise effort one level OR narrow the scope of the brief)

## Budget Safeguards

- Hard ceilings from the effort table are invariants — never exceed them
- If a subagent runs long, terminate and collect partial findings rather than blocking the round
- If total spent tokens exceed 15× a normal chat turn at `max` effort (the Anthropic-reported ceiling), stop and produce a report from what you have with an explicit "budget exhausted" flag

## Integration

- Pairs with `structured-agentic-coding:masterplan-architect` — architect can call this skill to gather external evidence before clarifying questions
- Pairs with `structured-agentic-coding:codebase-pattern-match` (when implemented) — external findings get cross-referenced to local exemplars before producing recommendations
- Pairs with `structured-agentic-coding:verification-before-completion` — the CitationAgent pass at Step 6 is an instance of verification-before-completion applied to sources
