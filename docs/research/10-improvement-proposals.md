# Improvement Proposals for Structured Agentic Coding

**Research Date:** 2026-04-13
**Based on:** All research files in this directory

---

## Context

This file synthesizes all findings from the research phase into concrete improvement proposals for the structured-agentic-coding plugin. Proposals are organized by source and tagged with priority.

---

## From Tree-Sitter / Code Graph Research (01)

| # | Proposal | Priority | Rationale |
|---|----------|----------|-----------|
| 1 | Build tree-sitter MCP graph server (7 tools) | **Active** | Already in spec/plan. Graph improves accuracy 8-99% on SWE-bench (RepoGraph ICLR 2025) |
| 2 | Progressive disclosure on get_module_summary | **Active** | In plan. Matches Aider's token-budget-constrained approach |
| 3 | Config grep in blast_radius | **Active** | In plan. Covers tree-sitter blind spot for .json/.yaml/.csproj |
| 4 | get_changes_since for wave execution | **Active** | In plan. Enables fresh-context recovery |
| 5 | "Graph first, grep fallback" pattern | **Active** | In plan. Anthropic recommends grep; graph adds structural awareness |

## From Multi-Agent-Shogun (02)

| # | Proposal | Priority | Rationale |
|---|----------|----------|-----------|
| 6 | Purpose validation at task completion | High | Executor re-reads purpose before marking done. Catches "technically complete but wrong" |
| 7 | Bloom-based model routing per task | High | Classify tasks by complexity → cheaper models for simple work. Dynamic model: frontmatter |
| 8 | Batch QC gate | High | Execute batch 1, QC, then proceed. Never repeat flawed approach across all tasks |
| 9 | North Star field on masterplans | High | WHY this matters. Grill + reviewer check alignment |
| 10 | Acceptance criteria on every task | High | Extend WHAT/HOW/GUARD with ACCEPT: — specific testable conditions |
| 11 | "Exhaust before surrendering" rule | High | Require 2+ alternative approaches before marking blocked. Add to anti-patterns |
| 12 | Instruction build system | Medium | Assemble agents from shared fragments. CI detects drift. Prevents 20+ files diverging |
| 13 | SKIP = FAIL policy | Medium | Treat skipped tests as failures in verification phases |
| 14 | Skill candidate discovery | Medium | Agents flag reusable patterns (seen 2+ times) during execution |
| 15 | Critical thinking rule | Medium | "Verify assumptions, propose alternatives, report early, don't over-criticize" |
| 16 | Race condition prevention (RACE-001) | Medium | Formalize: no concurrent writes to same file. Already partial in executor |

## From ARIS (03)

| # | Proposal | Priority | Rationale |
|---|----------|----------|-----------|
| 17 | Cross-model adversarial review | High | Different model families for executor vs reviewer. Eliminates correlated blind spots |
| 18 | Reviewer memory + debate in grill sessions | High | Griller tracks suspicions. Architect rebuts. Rulings: SUSTAINED/OVERRULED |
| 19 | JSON state persistence + compact recovery | High | Write state after every phase. Survive context compaction/session recovery |
| 20 | Meta-optimize via hook-based usage logging | High | Log tool uses, failures, interventions. Periodically analyze to improve scaffold |
| 21 | Failed approach memory | Medium | Track dead ends as first-class artifacts. Prevent re-exploring dead ends |
| 22 | Effort levels with hard invariants | Medium | Configurable depth but review quality, test requirements never scale down |
| 23 | Configurable human checkpoints | Medium | AUTO_PROCEED: true/false between phases |
| 24 | "Exhaust before surrendering" rule | Medium | (Same as #11, cross-validated by ARIS) |

## From Claude Code Best Practices (04)

| # | Proposal | Priority | Rationale |
|---|----------|----------|-----------|
| 25 | SessionStart hook for graph health | **Active** | In plan. Matches check-upgrade.sh pattern |
| 26 | AGENTS.md regeneration preservation | **Active** | In plan. Critical — almost lost agent discovery |
| 27 | PTC (Programmatic Tool Calling) awareness | Low | Design graph tool responses for composable queries |
| 28 | Deferred tool loading awareness | Low | Keep MCP tool descriptions concise (<10% context) |

## From Multi-Agent Parallel Worktrees (05)

| # | Proposal | Priority | Rationale |
|---|----------|----------|-----------|
| 29 | Level 1: Multiple masterplans on separate worktrees | High | Zero coupling. Each executor runs independently. Merge PRs at end |
| 30 | Level 2: Parallel tasks within masterplan via worktree subagents | Medium | Use `isolation: worktree` on subagents for file-disjoint tasks. Already have file-overlap detection |
| 31 | Cross-masterplan file overlap pre-flight check | Medium | Before running parallel masterplans, verify no overlapping files |
| 32 | Clash integration for conflict detection | Low | PreToolUse hook, in-memory three-way merge simulation |
| 33 | Cap at 3-5 parallel agents | **Active** | Already in executor (max 3). Data confirms this is optimal |
| 34 | Time-based agent checkpointing | Medium | Success rate drops after 35 min. Add state persistence for long phases |

## From Containerized Agent Development (06)

| # | Proposal | Priority | Rationale |
|---|----------|----------|-----------|
| 35 | Sandcastle integration for safe parallel execution | High | TypeScript API, git worktree management, Docker isolation |
| 36 | Docker Sandboxes as default for yolo mode | Medium | `sbx run claude` — strongest local isolation (microVM), single command |
| 37 | Anthropic srt for lightweight sandboxing | Medium | Near-zero overhead, 84% fewer permission prompts |
| 38 | Credential proxy pattern | Low | API keys never enter sandbox. Proxy injects on host side |

## From LLM Agentic Coding Papers (07)

| # | Proposal | Priority | Rationale |
|---|----------|----------|-----------|
| 39 | Plan-then-execute pattern (already have) | **Active** | Universal across top systems. Our masterplan system is this |
| 40 | ACI design awareness | Medium | Interface design matters as much as model (SWE-agent +40%). Our agent tool descriptions are our ACI |
| 41 | Bug reproduction before fix | Medium | MarsCode Agent pattern: write reproducing test first. Add to executor |
| 42 | Flow engineering > prompt engineering | **Active** | Our entire scaffold is flow engineering. Validates approach |
| 43 | Self-repair diminishing returns after 2 rounds | **Active** | Already in executor (max 3 fix loops). Data says 2 is often enough |
| 44 | Agentless-style hierarchical localization | Low | Could add to impact-analyst: narrow from repo → file → function → lines |
| 45 | Specification-guided generation | Low | Generate formal specs before code. Future research direction |

## From AI Code Review Systems (08)

| # | Proposal | Priority | Rationale |
|---|----------|----------|-----------|
| 46 | Integrate static analysis (SonarQube/Semgrep) with LLM review | High | 100% bug resolution at <$35 for 7500 issues. SAST-Genius: 91% false positive reduction |
| 47 | Multi-review aggregation | Medium | SWR-Bench: +43.67% F1 by aggregating 10 reviews. Run multiple passes and merge |
| 48 | ast-grep MCP as complement to tree-sitter graph | Low | Structural search for pattern matching in review workflows |
| 49 | Codebase-Memory validates our approach | **Active** | Tree-sitter graph via MCP: 10x fewer tokens, 2.1x fewer tool calls (March 2026 paper) |
| 50 | Cross-file dependency in code review | Medium | CodeRabbit + Augment do this. Our blast_radius enables it |
| 51 | LLM-generated code smell monitoring | Medium | GitClear: 8x increase in duplicated code. Our scan playbooks are critical quality gate |

## From Context Engineering (09)

| # | Proposal | Priority | Rationale |
|---|----------|----------|-----------|
| 52 | Observation masking for long masterplan execution | High | JetBrains: 52% cheaper, better performance than summarization. Replace old tool results with placeholders |
| 53 | KV-cache-friendly prompt design | High | Manus: 10x savings with stable prefixes. No timestamps in system prompts. Append-only contexts |
| 54 | Plan caching from completed masterplans | High | 50.31% cost reduction, 27.28% latency reduction, 96.61% performance (OpenReview) |
| 55 | Multi-model cascade routing | High | CascadeFlow: 40-85% cost reduction. 87% with well-implemented cascade |
| 56 | Todo recitation pattern | Medium | Manus: agents maintain todo.md pushing objectives into recent attention. Prevents lost-in-middle |
| 57 | Preserve error traces in context | Medium | Manus: keep failed actions. Model implicitly updates beliefs, reduces repeated mistakes |
| 58 | Sub-agent fresh context architecture | **Active** | Already in our executor. Each subagent gets fresh 200K window. Validated by Anthropic |
| 59 | Grep + graph hybrid (not graph alone) | **Active** | GrepRAG: grep succeeded in 161 cases where ALL embedding baselines failed. Our "graph first, grep fallback" is validated |
| 60 | Context compaction at 50% not 83% | Medium | Anthropic recommends manual /compact at 50%. Their auto at 83% is too late for quality |

## From Scheduled/Deferred Agents (11) — COMPLETE

| # | Proposal | Priority | Rationale |
|---|----------|----------|-----------|
| 61 | /schedule integration for overnight masterplan execution | High | Claude Code native cloud tasks. Run architect overnight, review in morning. claude/ branch prefix prevents main corruption |
| 62 | Scheduled security scanning agent | High | Combine scan playbooks with /schedule + Sentry MCP + SonarQube MCP + Semgrep for periodic audits. Snyk Agent Scan for skill supply chain |
| 63 | ARIS-style JSON state persistence for long-running tasks | High | State files + stale detection (>24h) + compact recovery. ARIS proves this works for overnight pipelines |
| 64 | Cross-model adversarial review on schedule | High | Managed Agents API ($0.08/session-hr) for nightly review by different model family. Eliminates correlated blind spots |
| 65 | Ralph Wiggum circuit breaker in executor | Medium | 3-no-progress / 5-same-error circuit breaker + session expiration. Proven safety pattern for autonomous loops |
| 66 | Event-triggered scan playbooks (Cursor Automations pattern) | Medium | On PR merge: scan changed files. On Sentry alert: investigate. On Linear issue: generate plan |
| 67 | CI/CD continuous AI integration | Medium | Claude Code GitHub Actions for PR review + Semgrep + SonarQube + Dependabot AI agent assignment |
| 68 | Weekly proactive codebase health report | Medium | Scheduled agent runs all scans, checks coverage, analyzes debt, generates CODEBASE_HEALTH.md |
| 69 | Multi-platform notification for scheduled results | Low | Ductor/Hermes pattern: results to Telegram/Slack, developer reviews on phone |
| 70 | Self-improving skill creation post-masterplan | Low | Hermes pattern: after completion, write reusable skill from experience. Skills improve during use |
| 71 | Isolated sessions for scheduled tasks | Low | OpenClaw pattern: scheduled tasks get own context window, don't pollute dev session |
| 72 | Scheduled graph health and AGENTS.md refresh | Low | SessionStart hook covers some, but scheduled deep-refresh useful |

---

## Priority Matrix

### Already Active (in current spec/plan)
1, 2, 3, 4, 5, 25, 26, 33, 39, 42, 43, 49, 58, 59

### Tier 1: High Priority for Next Release
6, 7, 8, 9, 10, 11, 17, 18, 19, 20, 29, 46, 52, 53, 54, 55, 61, 62, 63, 64

### Tier 2: Medium Priority
12, 13, 14, 15, 16, 21, 22, 23, 30, 31, 34, 35, 40, 41, 47, 50, 51, 56, 57, 60, 65, 66, 67, 68

### Tier 3: Lower Priority / Future
27, 28, 32, 36, 37, 38, 44, 45, 48, 69, 70, 71, 72

---

## Cross-Cutting Themes

1. **Structured workflows beat prompt engineering** — AlphaCodium, MetaGPT, all successful agents
2. **Context quality is the #1 determinant** — Anthropic, Cursor, Stripe, Augment all converge
3. **3-5 parallel agents is the sweet spot** — Google Research, Anthropic, industry consensus
4. **Self-repair saturates after 2 rounds** — invest in getting initial generation right
5. **Multi-agent error amplification is real (17x)** — structured topology prevents it
6. **Graph-based navigation improves accuracy, not necessarily tokens** — RepoGraph ICLR 2025, Codebase-Memory 2026
7. **Cross-model review eliminates correlated blind spots** — ARIS key innovation
8. **Containerized execution is mandatory for autonomous agents** — OWASP, McKinsey red-team
9. **Projects with good context files: 40% fewer errors, 55% faster** — Anthropic 2026 report
10. **Self-improving agents are viable** — Bristol 17%→53%, Meta-Harness 80% effort reduction
11. **Grep beats embeddings for code** — GrepRAG: 35x faster, succeeded where all embedding baselines failed
12. **Observation masking > summarization for cost** — JetBrains: 52% cheaper, summarization made agents run 13-15% longer
13. **KV-cache optimization is the #1 cost lever** — Manus: 10x savings with stable prefixes
14. **Plan caching saves 50% costs** — reuse plan templates from completed executions
15. **Multi-model routing saves 31-87%** — route simple tasks to cheap models
16. **Static analysis + LLM outperforms either alone** — IRIS doubled detection, SAST-Genius 91% fewer false positives
17. **SWR-Bench reality: top F1 only 19.38%** — automated review is still immature, human-in-loop mandatory
18. **AI code quality is degrading codebases** — GitClear: 8x duplicated code, refactoring dropped 25%→<10%
