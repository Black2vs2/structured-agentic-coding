# ARIS (Auto-Research-In-Sleep): Autonomous Agent Pipeline Patterns

**Research Date:** 2026-04-13
**Source:** github.com/wanshuiyin/Auto-claude-code-research-in-sleep (6,449 stars, MIT license)

---

## 1. What It Is

ARIS is a Markdown-only skill harness for autonomous ML research. 60+ SKILL.md files that instruct LLM agents (Claude Code, Codex CLI, Google Antigravity, OpenClaw) to orchestrate the full ML research lifecycle: literature survey → idea generation → experiment execution → iterative review → paper writing → rebuttal.

A researcher starts Claude Code before bed. Overnight, the system autonomously surveys literature, generates and pilot-tests ideas, verifies novelty, implements experiments, runs adversarial review loops, and writes a paper draft.

## 2. Skill-Based Architecture

Each skill is a `SKILL.md` file with:
- YAML frontmatter: `name`, `description`, `argument-hint`, `allowed-tools`
- Markdown body: structured step-by-step instructions
- Invoked via `/skill-name "arguments"` slash commands

### Workflow Chaining via Artifact Contracts

Skills compose into pipelines through plain-text files as interfaces:

```
/idea-discovery → IDEA_REPORT.md → /experiment-bridge → EXPERIMENT_LOG.md → /auto-review-loop → AUTO_REVIEW.md → /paper-writing → paper/main.pdf
```

Key workflows:
- **W1: Idea Discovery** — research-lit → idea-creator → novelty-check → research-review → research-refine-pipeline
- **W1.5: Experiment Bridge** — parse plan, implement code, GPT code review, sanity check, deploy, collect results
- **W2: Auto Review Loop** — up to N rounds of external review → implement fixes → re-review until score threshold
- **W3: Paper Writing** — paper-plan → paper-figure → paper-write → paper-compile → auto-paper-improvement-loop
- **W4: Rebuttal** — stress-test responses to reviewer concerns

## 3. Cross-Model Adversarial Collaboration (Key Innovation)

**Executor and reviewer must be different model families.** Claude Code (executor) writes code. GPT-5.4/Gemini/GLM (reviewer) critiques, scores, demands revisions. Eliminates correlated blind spots.

### Reviewer Independence Protocol

Executor passes ONLY file paths to reviewer — never summaries, interpretations, or curated context. Reviewer reads raw artifacts and forms own assessment.

**CAN pass:** role/persona, review objective, file paths, structural metadata, venue constraints.
**CANNOT pass:** executor summaries, interpretations, recommendations, leading questions, previous feedback.

### Three Difficulty Levels
- **Medium:** MCP-based review. Claude controls what context GPT sees.
- **Hard:** Adds Reviewer Memory (GPT tracks suspicions across rounds) + Debate Protocol (Claude rebuts, GPT rules SUSTAINED/OVERRULED/PARTIALLY SUSTAINED).
- **Nightmare:** GPT reads the repo directly via `codex exec`. Claude cannot filter what GPT sees. GPT independently verifies reported numbers match actual output files.

### Experiment Integrity Protocol
Model that writes experiment code must NOT judge its own integrity. Prohibited: fake ground truth, score normalization fraud, phantom results, insufficient scope misrepresentation.

## 4. State Persistence and Recovery

### JSON State Files
`REVIEW_STATE.json` persists after every round:
```json
{
  "round": 2,
  "threadId": "019cd392-...",
  "status": "in_progress",
  "difficulty": "medium",
  "last_score": 5.0,
  "pending_experiments": ["screen_name_1"],
  "timestamp": "2026-03-13T21:00:00"
}
```

### Context Window Survival (Compact Recovery)
1. Read `REVIEW_STATE.json` to recover round number, thread ID, score
2. Read `AUTO_REVIEW.md` (cumulative log)
3. If `COMPACT = true`, read `findings.md` + `EXPERIMENT_LOG.md` instead of full logs
4. Resume at next round

### Stale State Detection
Before reading any state file, check age. If >24 hours, warn: "State file is N hours old. May be from previous research direction. Continue or start fresh?"

### Research Contract (Context Compression)
After brainstorming produces 8-12 ideas, chosen idea extracted into `RESEARCH_CONTRACT.md` — focused standalone document. New sessions load this instead of full idea pool.

### Output Versioning
Every output gets timestamped copy (`IDEA_REPORT_20250615_143022.md`) plus fixed-name latest (`IDEA_REPORT.md`). Downstream skills always read fixed-name. Timestamped files never deleted.

## 5. Effort Levels with Hard Invariants

Every skill accepts `effort: lite | balanced | max | beast` controlling breadth/depth/iterations.

Hard invariants (reviewer quality, citation integrity, experiment integrity) NEVER change regardless of effort. Only the number of papers, ideas, rounds, etc. scale.

## 6. Human Checkpoint Gates

`HUMAN_CHECKPOINT = true/false` and `AUTO_PROCEED = true/false` control whether pipeline pauses for human approval. Default autonomous, humans opt into control.

## 7. Graceful Degradation

If Codex MCP unavailable → fall back to llm-chat MCP. If that fails → Claude makes own judgment marked `[pending cross-model review]`. Pipeline never hard-blocks.

## 8. Auto-Debug Before Surrender

When sanity check fails:
1. Read error, classify (OOM, ImportError, FileNotFoundError, CUDA, NaN/divergence)
2. Apply targeted fix
3. Re-run. If attempt 2+ fails → call `/codex:rescue` (cross-model second opinion)
4. After 3 attempts → stop and report with all attempted fixes

### "Exhaust Before Surrendering" Rule
Before marking any concern as "cannot address":
1. Try at least 2 different solution paths
2. For experiment issues, adjust hyperparameters or try alternative baselines
3. For theory issues, provide weaker version or alternative argument
4. Only then concede narrowly and bound the damage

## 9. Research Wiki (Persistent Knowledge Base)

Four entity types: Papers, Ideas, Experiments, Claims. Typed relationships as JSONL edges.

### query_pack.md — Hard-Budgeted Context Summary
Max 8000 chars compressed summary regenerated after every mutation:
- Project direction (300 chars)
- Top gaps (1200 chars)
- Paper clusters (1600 chars)
- **Failed ideas (1400 chars — highest anti-repetition value)**
- Top papers (1800 chars)
- Active chains (900 chars)

**Failed ideas are explicitly the most valuable memory.** Never pruned. Prevents re-exploring dead ends.

## 10. Meta-Optimize: Self-Improving Harness

Based on Meta-Harness (Lee et al., Stanford, 2026).

### How It Works
1. **Passive logging via Claude Code hooks** — PostToolUse, PostToolUseFailure, UserPromptSubmit, SessionStart, SessionEnd append JSONL events to `.aris/meta/events.jsonl`
2. **Readiness check on SessionEnd** — counts skill invocations since last optimization; if >= 5, suggests `/meta-optimize`
3. **Analysis** — frequency, failure, convergence, human intervention analysis
4. **Patch proposals** — concrete diffs to SKILL.md files, citing specific event log data
5. **Cross-model review of patches** — GPT-5.4 reviews each proposed change
6. **User-approved application** — never auto-applies; backs up originals

### What It Optimizes
SKILL.md prompts, default parameters, convergence rules, workflow ordering. NOT artifact schemas or MCP config.

## 11. MCP Servers

- **claude-review** — Claude as reviewer via MCP
- **gemini-review** — Gemini as reviewer via MCP
- **llm-chat** — Generic OpenAI-compatible chat MCP
- **minimax-chat** — MiniMax-specific MCP
- **feishu-bridge** — Lark/Feishu notifications

## 12. Weaknesses

1. Research-domain specific, not general software engineering
2. Context window dependency — compact recovery is a workaround
3. No true parallel multi-agent — skills chain sequentially
4. Reviewer quality ceiling — can't replace human domain expertise
5. GPU infrastructure assumptions
6. Chinese ecosystem bias
7. No code graph understanding (grep/file path navigation only)
8. Experiment fraud detection is reactive
9. No formal verification of skill correctness
10. Windows support experimental

## 13. External Research Referenced

### Meta-Harness (Lee et al., Stanford, 2026)
arxiv.org/abs/2603.28052 — Harness design matters as much as model weights. Reduced coding effort by up to 80%. On TerminalBench-2, discovered harnesses surpass hand-engineered baselines.

### Karpathy's AutoResearch
github.com/karpathy/autoresearch — 630 lines of Python, one GPU, 700 experiments in 2 days, 20 optimizations discovered. Three components: agent with one modifiable file, one objective metric, fixed time limit.

### Anthropic 2026 Agentic Coding Trends Report
Projects with well-maintained context files: **40% fewer agent errors, 55% faster task completion**.

### MIT EnCompass Framework
Separates search strategy from underlying agent workflow. Reduced coding effort by up to 80%.

### Self-Improving Coding Agent (Robeyns, Bristol, 2025)
arxiv.org/html/2504.15228v1 — Agent improved from 17% to 53% on SWE-Bench Verified by editing its own prompts.

### Darwin Godel Machine (Sakana AI)
sakana.ai/dgm — Coding agent that reads and modifies its own Python codebase to self-improve.

## Sources

- github.com/wanshuiyin/Auto-claude-code-research-in-sleep
- deepwiki.com/wanshuiyin/Auto-claude-code-research-in-sleep
- arxiv.org/abs/2603.28052 (Meta-Harness)
- github.com/karpathy/autoresearch
- fortune.com/2026/03/17/andrej-karpathy-loop-autonomous-ai-agents-future/
- resources.anthropic.com/2026-agentic-coding-trends-report
- news.mit.edu/2026/helping-ai-agents-search-to-get-best-results-from-llms-0205
- arxiv.org/html/2504.15228v1 (Self-Improving Coding Agent)
- sakana.ai/dgm (Darwin Godel Machine)
