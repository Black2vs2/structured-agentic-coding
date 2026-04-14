# Multi-Agent Parallel Development with Git Worktrees

**Research Date:** 2026-04-13
**Sources:** Claude Code docs, Agent Teams, /batch, claude-squad, Composio, Overstory, ccswarm, Metaswarm, Clash, Augment Intent, Stripe Minions, Google Research, CodeCRDT, FeatureBench, academic papers

---

## Executive Summary

Running multiple agents in parallel on worktrees is feasible and increasingly well-supported. Success depends on task decomposition quality, file-overlap prevention, and sequential merge discipline. Consensus optimal range: **3-5 parallel agents**, diminishing returns beyond that. Unstructured multi-agent failure rates: 41-86%. Well-structured systems with file-level isolation report substantially higher success.

---

## 1. Claude Code Native Worktree Support

### The `--worktree` / `-w` Flag (CLI, v2.1.50+)

`claude --worktree feature-auth` creates `.claude/worktrees/<name>/` with branch `worktree-feature-auth` based on `origin/HEAD`.

- Automatic cleanup: no-change worktrees removed on exit
- Orphan cleanup: crashed subagent worktrees auto-pruned after `cleanupPeriodDays`
- `.worktreeinclude` copies gitignored files (.env, secrets) into new worktrees
- WorktreeCreate/WorktreeRemove hooks for custom VCS

### Subagent Worktree Isolation

`isolation: worktree` in subagent frontmatter → each dispatch gets own worktree automatically. Up to 10 subagents simultaneously, each with fresh 200K-token context window.

### Agent Teams (Experimental, v2.1.32+)

- Team lead + teammates + shared task list + mailbox messaging
- Shared task list: pending/in-progress/completed states, dependency tracking, file-lock task claiming
- Direct teammate-to-teammate messaging, broadcast capability
- Quality gates: TeammateIdle, TaskCreated, TaskCompleted hooks
- Recommended: 3-5 teammates, 5-6 tasks per teammate
- Limitations: no session resumption, no nested teams, one team per session

### The `/batch` Command (v2.1.63+)

1. Orchestrator enters plan mode, launches Explore agent to scan codebase
2. Decomposes into 5-30 independent units
3. After approval, spawns one background agent per unit in parallel
4. Each agent gets worktree isolation
5. Each worker runs /simplify, tests, commits, pushes, opens PR

Designed for **homogeneous migrations** (same transformation across many files), not heterogeneous multi-phase masterplans.

### Boris Cherny's Daily Workflow

Runs 10-15 simultaneous sessions (5 terminal + 5-10 browser). Three mandatory criteria:
1. No dependencies between tasks
2. No shared file state
3. Each task describable in one sentence

Check at 5 minutes, then every 15-20 minutes. "Constantly interrupting mid-execution degrades output quality."

## 2. External Multi-Agent Tools

### claude-squad
- Terminal manager for multiple AI agents using tmux + worktrees
- No inter-agent communication — isolation IS coordination
- Manual review via diff/preview tabs
- github.com/smtg-ai/claude-squad

### Composio Agent Orchestrator
- Fleet coordinator: one issue = one agent instance
- Worktree or full clone per agent
- CI failures route back to originating agent (max 2 retries, 30min timeout)
- Supports Claude Code, Codex, Aider, Cursor, OpenCode
- 3,288 test cases, 921 commits, 61 merged PRs internally
- github.com/ComposioHQ/agent-orchestrator

### Overstory
- Orchestrator → Coordinator → Workers (Scout, Builder, Reviewer, Merger) + Monitor
- SQLite WAL mail system (~1-5ms per query), 8 message types
- FIFO merge queue with 4-tier conflict resolution
- 11 supported runtimes
- Token/cost analysis per agent, timeline visualization
- github.com/jayminwest/overstory

### ccswarm
- Actor model with role-based agents, Rust channel message passing
- Worktree auto-management per agent
- ParallelExecutor not yet integrated (sequential only in practice)
- github.com/nwiizo/ccswarm

### Metaswarm
- Swarm-of-swarms with recursive spawning, 18 agent personas
- Design Review Gate (5 specialists, 3-iteration cap), Plan Review Gate (3 adversarial reviewers)
- TDD enforcement, mandatory test-first
- github.com/dsifry/metaswarm

### Clash (Conflict Detection)
- Early worktree-to-worktree conflict detection
- `git merge-tree` via gix library, three-way merges in-memory (read-only)
- Claude Code PreToolUse hook on Write/Edit operations
- Conflict matrix, per-file JSON reports, watch mode with TUI
- github.com/clash-sh/clash

### Augment Code Intent
- Coordinator → 6 Specialists (Investigate, Implement, Verify, Critique, Debug, Code Review) → Verifier
- "Living Spec" shared across all agents, auto-updates
- Each workspace backed by own worktree

## 3. Stripe Minions: Enterprise Scale (1,300+ PRs/week)

- Each Minion gets own EC2 instance (prewarmed pool, 10-second spin-up)
- No internet or production access
- Agent harness forked from Block's Goose
- Deterministic orchestrator prefetches context before LLM wakes up
- ~500 MCP tools available, agents receive "intentionally small subset" per task
- Rule files scoped to specific subdirectories
- Three million tests available for feedback
- During "Atlas Fix-It Week," Minions resolved 30% of all bugs autonomously

## 4. Success Rates and Failure Data

| Metric | Value | Source |
|--------|-------|--------|
| Multi-agent failure rate (unstructured) | 41-86.7% | TDS: 17x Error Trap |
| AI-generated PR rejection rate | 67.3% (vs 15.6% manual) | LinearB |
| Human-curated specs success improvement | +4% | Addy Osmani |
| AI-generated AGENTS.md success reduction | -3% with 20% higher cost | Addy Osmani |
| incident.io concurrent agents/developer | 4-7 | Anthropic case study |
| "3 focused agents > 1 generalist 3x longer" | Consistent finding | Multiple |

### Why Multi-Agent Systems Fail

1. **Coordination Tax**: Accuracy saturates beyond 4-agent threshold. 8 agents add 4+ seconds coordination latency.
2. **Context Fragmentation**: Agent A's output truncated when passed to B. Critical details drop.
3. **Infinite Loop Failures**: Conflicting instructions cause bounce-back without resolution.
4. **Error Amplification (17x Trap)**: 5 agents at 90% accuracy = 59% end-to-end. 10 agents = 35%. Fix: structured topology, not more agents.

## 5. Academic Research

### Google Research: "Towards a Science of Scaling Agent Systems" (Dec 2025)

180 agent configurations, 4 benchmarks:

| Task Type | Multi-Agent Impact |
|-----------|-------------------|
| Parallelizable (Finance-Agent) | +81% improvement |
| Sequential (PlanCraft) | -70% degradation |
| General sequential reasoning | -39% to -70% |
| Error amplification (independent) | 17.2x |
| Error amplification (centralized) | 4.4x |
| Optimal strategy prediction | 87% accuracy |

**The Alignment Principle**: Multi-agent dramatically improves parallelizable tasks but degrades sequential ones.

### CodeCRDT: Observation-Driven Coordination (EuroSys 2025)

Lock-free parallel code generation using CRDTs:

| Metric | Result |
|--------|--------|
| Maximum speedup | 21.1% |
| Maximum slowdown | 39.4% |
| Convergence rate | 100% (zero merge failures) |
| Runtime improvement | +25% |
| Code quality degradation | -7.7% |

### FeatureBench (ICLR 2026)

Complex feature development (200 instances):
- Claude 4.5 Opus: 11.0% resolved
- GPT-5.1-Codex: 12.5% resolved

Multi-file multi-step features remain extremely hard.

### "Agentic Software Engineering" Survey (2025)

| Metric | Value |
|--------|-------|
| "Plausible" fixes introducing regressions | 29.6% |
| GPT-4 true solve rate after audit | 3.97% (down from 12.47%) |
| Agent PRs facing long delays | 68%+ |

## 6. Merge Strategies

| Strategy | Used By |
|----------|---------|
| Sequential rebase | Most manual workflows |
| FIFO merge queue | Overstory |
| AI-assisted resolution | Agent Orchestrator, Agent Teams |
| Single-writer rule | Best practice everywhere |
| Additive-only pattern | Conflict prevention |
| Pre-merge conflict detection | Clash |

**Key Finding:** Git has no cross-worktree conflict warning. Must use external tools or pre-assign file domains.

## 7. Scale Limits

| Dimension | Finding |
|-----------|---------|
| Recommended local agents | 3-5 |
| Practical ceiling (local) | 5-7 |
| Maximum documented | 371 worktrees (anecdotal) |
| Stripe production | 1,300+ PRs/week |
| Time degradation threshold | After 35 min, doubling duration 4x failure rate |
| Disk usage | 9.82 GB for worktrees in 20-min session on ~2GB codebase |
| Token cost | Linear with agent count |
| Sequential task degradation | -39% to -70% |
| Parallelizable improvement | Up to +81% |
| ROI threshold | Tasks under 30 min don't justify 5-10 min setup |

## 8. What Works vs What Doesn't

### Works Well
- Independent features/modules in parallel (+2-4x throughput)
- Documentation, tests, refactoring in parallel
- Bug fixes across different modules (Stripe: 30% autonomously)
- Research/review with competing hypotheses
- 3-5 concurrent agents with explicit file ownership

### Does Not Work
- Sequential tasks forced parallel (-39% to -70%)
- Shared config file editing (guaranteed conflicts)
- Architecture decisions requiring consensus
- Tasks under 30 minutes (setup overhead exceeds benefit)
- More than 7 local agents
- Long-running agents without checkpoints (degrades after 35 min)
- Complex multi-file features (11-12.5% success even for frontier)

## Sources

- code.claude.com/docs/en/common-workflows
- code.claude.com/docs/en/agent-teams
- threads.com/@boris_cherny
- towardsdatascience.com (17x Error Trap, parallel agents)
- addyosmani.com/blog/code-agent-orchestra
- engineering.intility.com (Agent Teams & Worktrees)
- stripe.dev/blog/minions
- research.google (Scaling Agent Systems)
- arxiv.org (CodeCRDT, FeatureBench, Agentic SE survey)
- github.com repos: claude-squad, agent-orchestrator, overstory, ccswarm, metaswarm, clash, parallel-worktrees
- augmentcode.com
- shareuhack.com (parallel workflow guide)
