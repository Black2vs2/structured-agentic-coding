# Roadmap Proposal: Structured Agentic Coding v4.0 → v6.0

**Date:** 2026-04-13
**Based on:** 11 research files, 72 improvement proposals, 18 cross-cutting themes, 30+ papers, 20+ tools analyzed

---

## Current State: v3.2.0

- 19 agents (7 base + 12 Angular/.NET profile)
- 31 scan playbooks (12 BE + 19 FE), 189 rules
- Masterplan workflow: Architect → Executor → Reviewer
- CODEMAP.md bulk-loading for codebase navigation
- Grep-based scan playbooks for code review
- 2 skills: scaffold + upgrade
- No graph understanding, no parallel execution, no scheduling, no sandboxing

---

## v4.0 — "Graph + Grill" (already in spec/plan)

**Theme:** Replace codemap bulk-loading with intelligent graph queries. Stress-test designs before implementation.

### Phase A: Code Graph MCP Server

| What | Details | Proposal # |
|------|---------|-----------|
| Tree-sitter MCP server | 7 tools + rebuild + agents manifest. Python, SQLite, NetworkX | 1 |
| Progressive disclosure | `get_module_summary(depth=1/2/3)` — counts first, details on demand | 2 |
| Ranked search | `find_symbol` with exact > prefix > contains scoring | — |
| Config grep hybrid | `get_blast_radius` includes grep for .json/.yaml/.csproj blind spots | 3 |
| Wave execution support | `get_changes_since(commit)` — symbol-level diffs for fresh-context recovery | 4 |
| Graph-first, grep-fallback | All agents instructed: graph for structure, grep for text patterns | 5 |
| SessionStart hook | Graph health check prints status on session start | 25 |
| AGENTS.md preservation | MCP tool for agent manifest regeneration (replaces codemap-updater) | 26 |
| Lazy indexing | Auto-build on first query, incremental on git hash change | — |
| Remove codemaps | Kill codemap-updater agent, /update-codemaps command, all CODEMAP.md refs | — |
| Upgrade migration | Post-upgrade guided cleanup for existing projects | — |

### Phase B: Architect Grill Session

| What | Details | Proposal # |
|------|---------|-----------|
| Self-grill | Architect interrogates own plan across 6 categories before presenting | — |
| User-grill | Walk user through max 25 questions with recommended answers | — |
| Grill log | Appended to masterplan with question/answer/revision table | — |

**Estimated effort:** 20 tasks, ~17 commits. Already fully spec'd and planned.

---

## v4.1 — "Smarter Execution"

**Theme:** Make the executor smarter, cheaper, and more reliable. Low-risk changes to existing agent files.

### Executor Improvements

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **Purpose validation** | After executing task, re-read original purpose. Verify deliverable matches before marking done. Add to executor step 2e. | 6 | Small — add 5 lines to executor |
| **Acceptance criteria** | Extend WHAT/HOW/GUARD with `ACCEPT:` field. Executor validates ALL criteria. Add to masterplan template + executor. | 10 | Small — template + executor change |
| **North Star field** | Add `North Star:` to masterplan template. Grill session + reviewer check alignment. | 9 | Small — template change |
| **Batch QC gate** | For repetitive phases (3+ similar tasks): execute first task, QC, proceed only if pass. Add to executor step 2b. | 8 | Medium — executor logic |
| **"Exhaust before surrendering"** | Require 2+ alternative approaches before escalating. Add to anti-patterns.md + executor escalation section. | 11 | Small — anti-patterns + executor |
| **Bug reproduction first** | Before fixing, write a test that reproduces the issue. Add to executor's BE/FE dispatch prompts for fix tasks. | 41 | Small — prompt change |
| **Circuit breaker** | 3-no-progress / 5-same-error circuit breaker in fix loop. Add session expiration for long phases. | 65 | Medium — executor logic |
| **SKIP = FAIL** | In verification phases, treat skipped tests as failures. Add to executor phase verification step 2f. | 13 | Small — one condition |

### Cost Optimization

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **Bloom-based model routing** | Classify tasks by complexity in masterplan. Simple tasks (copy, template, rename) → haiku/sonnet. Complex (architecture, root cause) → opus. Architect assigns `bloom_level:` per task, executor routes to appropriate model. | 7, 55 | Medium — architect template + executor routing |
| **KV-cache-friendly prompts** | Stable prefixes in agent system prompts. No timestamps. Append-only contexts. Reorder executor dispatch prompts so static parts come first. | 53 | Medium — audit all 19 agent files |
| **Observation masking** | In long masterplan execution, replace old tool results with placeholders instead of LLM summarization. 52% cheaper (JetBrains data). Add to executor for phases beyond phase 3. | 52 | Medium — executor enhancement |

### Agent Quality

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **Critical thinking rule** | Add to anti-patterns: "Verify assumptions. Propose alternatives when better. Report problems early. Don't over-criticize to paralysis." | 15 | Small — anti-patterns edit |
| **Preserve error traces** | Executor keeps failed actions in context for subagents. Model implicitly updates beliefs. | 57 | Small — executor prompt change |
| **Race condition prevention** | Formalize RACE-001: no concurrent writes to same file. Already partial in executor step 2a — document explicitly. | 16 | Small — executor + anti-patterns |

**Estimated effort:** ~15 changes, mostly to masterplan-architect.md, masterplan-executor.md, anti-patterns.md. No new infrastructure.

---

## v4.2 — "Adversarial Review"

**Theme:** Cross-model review and static analysis integration. Catch bugs the current system misses.

### Cross-Model Review

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **Different model for reviewer** | Code reviewer agents use a different model family from executor. Pass file paths only, never summaries. Eliminates correlated blind spots. | 17, 64 | Medium — reviewer agent model: frontmatter + prompt changes |
| **Reviewer independence protocol** | Reviewer reads raw code, not executor's description. Add to reviewer dispatch prompt. | 17 | Small — prompt change |
| **Reviewer memory + debate** | In grill sessions: griller tracks suspicions across rounds. Architect rebuts. Griller rules SUSTAINED/OVERRULED/PARTIALLY SUSTAINED. | 18 | Medium — architect agent enhancement |
| **Multi-review aggregation** | Run reviewer 3x, merge findings. +43.67% F1 (SWR-Bench). Add as option in executor targeted review step. | 47 | Medium — executor enhancement |

### Static Analysis Integration

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **SonarQube MCP integration** | Connect to existing SonarQube via MCP. Use in code review workflow alongside scan playbooks. 100% bug resolution demonstrated. | 46 | Medium — new skill + reviewer prompt |
| **Semgrep MCP integration** | Semgrep Claude Code plugin for structural pattern matching. Complements grep-based playbooks. | 46 | Medium — similar to above |
| **Cross-file dependency review** | Reviewer uses `get_blast_radius` to check if changes affect other files not in the PR. CodeRabbit + Augment pattern. | 50 | Small — reviewer prompt change |
| **LLM code smell monitoring** | Track duplicated code, refactoring ratio over time. GitClear: 8x increase in AI-generated duplication. | 51 | Medium — new scan playbook + tracking |

**Estimated effort:** ~10 changes. Reviewer agents, architect agent, new MCP integrations.

---

## v5.0 — "Parallel + Autonomous"

**Theme:** Multi-masterplan parallel execution, scheduled overnight tasks, containerized safety.

### Parallel Execution

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **Level 1: Parallel masterplans on worktrees** | Each masterplan gets own worktree via `claude --worktree`. Executors run independently. Merge PRs at end. | 29 | Medium — new orchestrator command/skill |
| **Level 2: Worktree subagents within masterplan** | Executor dispatches file-disjoint tasks with `isolation: worktree`. Sequential merge after batch. Already have file-overlap detection. | 30 | Medium — executor enhancement |
| **Cross-masterplan overlap check** | Before running parallel masterplans, verify no overlapping file paths. | 31 | Small — pre-flight script |
| **Clash integration** | PreToolUse hook for early conflict detection across worktrees. In-memory three-way merge simulation. | 32 | Low — optional hook |

### Scheduled Execution

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **Overnight masterplan execution** | `/schedule` integration. Architect runs overnight, produces masterplan. User reviews in morning. claude/ branch prefix safety. | 61 | Medium — new skill wrapping /schedule |
| **Scheduled security scanning** | Combine scan playbooks with /schedule + Sentry MCP + SonarQube MCP. Weekly/nightly audits. | 62 | Medium — new scheduled skill |
| **Event-triggered playbooks** | On PR merge: scan changed files. On Sentry alert: investigate. On Linear issue: generate plan. Cursor Automations pattern. | 66 | Large — hook infrastructure |
| **Weekly codebase health report** | Scheduled agent runs all scans, checks coverage, analyzes debt, generates CODEBASE_HEALTH.md. | 68 | Medium — new scheduled skill |

### State Persistence

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **JSON state files per phase** | Write state after every executor phase. Survive context compaction and session crashes. | 19, 63 | Medium — executor enhancement |
| **Stale state detection** | If state file >24h old, warn before resuming. | 63 | Small — one check |
| **Compact recovery** | On session restart, read state + compact summaries instead of full history. | 19 | Medium — executor enhancement |
| **Time-based checkpointing** | Agent success drops after 35 min. Force checkpoint and fresh context for long phases. | 34 | Medium — executor enhancement |

### Containerized Execution

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **Sandcastle integration** | For parallel execution: each agent in Docker container with git worktree bind-mount. TypeScript API. | 35 | Large — new infrastructure |
| **Docker Sandboxes for yolo mode** | Document `sbx run claude` as recommended safe execution mode. microVM isolation. | 36 | Small — documentation |
| **Anthropic srt recommendation** | Document `srt` as lightweight alternative. 84% fewer permission prompts. | 37 | Small — documentation |

**Estimated effort:** Large release. New skills, executor enhancements, infrastructure.

---

## v5.1 — "Agent Intelligence"

**Theme:** Configurable effort levels, human checkpoints, failed approach memory.

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **Effort levels** | `effort: lite / balanced / max / beast` on masterplans. Controls: number of grill questions, review passes, scan depth. Hard invariants: review quality, test requirements NEVER scale down. | 22 | Medium — architect + executor |
| **Configurable human checkpoints** | `AUTO_PROCEED: true/false` between phases. User controls autonomy level without changing workflow. Default: pause between phases. | 23 | Small — executor config |
| **Failed approach memory** | Track dead-end approaches as first-class artifacts in `.claude/failed-approaches/`. Include in architect context. Prevent re-exploring dead ends. | 21 | Medium — new persistence mechanism |
| **Skill candidate discovery** | Agents flag reusable patterns during execution (seen 2+ times → report as potential skill). Masterplan reviewer collects these. | 14 | Medium — reviewer enhancement |
| **Todo recitation** | Agents maintain todo.md pushing objectives into recent attention. Prevents lost-in-middle drift in long executions. | 56 | Small — executor prompt change |

---

## v6.0 — "Self-Improving System"

**Theme:** The system improves itself over time. Meta-optimization, plan caching, instruction composition.

### Self-Improvement

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **Meta-optimize via usage logging** | PostToolUse, SessionEnd hooks log JSONL events. Periodically analyze: which prompts fail? Where do users intervene? Which defaults get overridden? Propose improvements to scaffold rules. | 20 | Large — hook infrastructure + analysis skill |
| **Plan caching** | Cache masterplan templates from completed executions. Reuse for similar features. 50.31% cost reduction, 96.61% performance. | 54 | Large — caching infrastructure |
| **Self-improving skill creation** | After masterplan completion, agent writes reusable skill from experience. Skills improve during use. Hermes pattern. | 70 | Medium — new post-execution step |

### Infrastructure

| What | Details | Proposal # | Effort |
|------|---------|-----------|--------|
| **Instruction build system** | Assemble agent instructions from shared fragments (common rules + role-specific + profile-specific). CI detects drift between 19+ agent files. Shogun's `build_instructions.sh` pattern. | 12 | Large — refactor all agents |
| **CI/CD continuous AI integration** | GitHub Actions for PR review + Semgrep + SonarQube + Dependabot AI agent assignment. | 67 | Large — CI/CD setup |
| **ACI design audit** | Audit all agent tool descriptions as the Agent-Computer Interface. SWE-agent showed +40% from better ACI. | 40 | Medium — audit + rewrite |

---

## Release Sizing Summary

| Version | Theme | New Proposals | Estimated Tasks | Breaking Changes |
|---------|-------|--------------|----------------|-----------------|
| **v4.0** | Graph + Grill | 14 (active) | 20 | Yes — removes codemap system |
| **v4.1** | Smarter Execution | 14 | ~15 | No — agent file edits only |
| **v4.2** | Adversarial Review | 8 | ~10 | No — additive |
| **v5.0** | Parallel + Autonomous | 13 | ~25 | Minor — new executor capabilities |
| **v5.1** | Agent Intelligence | 5 | ~10 | No — additive |
| **v6.0** | Self-Improving | 6 | ~20 | Yes — agent file restructure |

---

## What NOT to Build (validated by research)

| Rejected Idea | Why | Source |
|---|---|---|
| Vector database / embeddings for code search | Grep beats embeddings for code. RAG failure mode is silent (wrong match). Anthropic tried and discarded. | GrepRAG, Anthropic, MindStudio |
| More than 5 parallel agents | Diminishing returns. Error amplification 17x for independent, 4.4x for centralized. | Google Research 2025 |
| Full autonomous execution without human gates | SWR-Bench: top F1 only 19.38%. 67.3% AI PR rejection rate. Human-in-loop mandatory. | LinearB, SWR-Bench |
| Fix loop beyond 3 iterations | Self-repair saturates after 2 rounds. Already at max 3, data says even 2 is usually enough. | ICLR 2024 |
| Custom fine-tuned models | Flow engineering > model tuning. System design around the LLM matters more. | AlphaCodium, all evidence |
| Single-agent for everything | "3 focused agents > 1 generalist 3x longer" — consistent across all sources. | Anthropic, Google, industry |

---

## Implementation Priority Recommendation

**Start with v4.0** (already spec'd and planned — 20 tasks ready to execute).

**Then v4.1** immediately after — it's all small changes to existing files. Purpose validation, acceptance criteria, North Star, batch QC, Bloom routing. High impact, low effort. Could ship same week as v4.0.

**Then v4.2** — cross-model review is the single highest-impact quality improvement from all research. Different model families for executor vs reviewer eliminates correlated blind spots. ARIS proves this works.

**v5.0 is the ambitious one** — parallel worktrees, scheduling, state persistence, containers. Plan carefully, ship incrementally.

**v5.1 and v6.0 are evolutionary** — self-improvement loops, plan caching, instruction build system. These compound over time.

---

## Key Metrics to Track (from research)

| Metric | Baseline | Target | Source |
|---|---|---|---|
| Token cost per masterplan | Unknown (measure) | -30% (v4.1 routing + masking) | Manus, JetBrains |
| Agent errors per masterplan | Unknown (measure) | -40% (better context) | Anthropic 2026 report |
| Task completion time | Unknown (measure) | -55% (graph + parallel) | Anthropic 2026 report |
| Code review finding rate | Grep-based (qualitative) | +43.67% F1 (multi-review) | SWR-Bench |
| Fix loop iterations needed | Max 3 (current) | Avg <2 (better initial generation) | ICLR 2024 |
| Masterplan rejection rate | Unknown | Track with purpose validation | Shogun |
| Dead-end re-exploration | Unknown | Zero (failed approach memory) | ARIS |
