# Multi-Agent-Shogun: Parallel Agent Orchestration Patterns

**Research Date:** 2026-04-13
**Source:** github.com/yohey-w/multi-agent-shogun (415+ stars, v4.4.2)
**License:** MIT

---

## 1. What It Is

multi-agent-shogun is a shell-based (100% bash) multi-agent orchestration system that runs up to 10 AI coding CLI instances in parallel — Claude Code, OpenAI Codex, GitHub Copilot, and Kimi Code — all coordinated through tmux panes using a feudal Japanese military hierarchy metaphor. Zero coordination overhead — agents communicate through YAML files on disk, not API calls.

## 2. Hierarchy

- **Lord** (human) — gives commands to Shogun
- **Shogun** (Claude Opus) — translates intent into commands, writes to YAML queue, immediately returns control to human
- **Karo** (Claude Sonnet Thinking) — the manager. Decomposes commands into subtasks, assigns to workers, makes OK/NG decisions, manages dashboard
- **Ashigaru 1-7** (configurable model per agent) — workers who execute tasks in parallel, each in own tmux pane
- **Gunshi** (Claude Opus) — strategist/quality checker. Handles Bloom L4-L6 analysis, architecture review, QC of worker output

### Key orchestration pattern
```
Lord speaks → Shogun writes YAML → inbox_write to Karo → Shogun ENDS TURN immediately
                                                          |
                                        Lord can give next command
                                                          |
                                 Karo decomposes → assigns to ashigaru in parallel
                                                          |
                                 Ashigaru complete → report to Gunshi → QC → Karo
                                                          |
                                 Dashboard updated (human-readable summary)
```

The Shogun's "Immediate Delegation Principle" is critical: writes a YAML entry and sends a single inbox notification, then STOPS. The human never waits.

## 3. Context Management — 4 Layers

1. **Memory MCP** — persistent across sessions (preferences, rules, lessons learned)
2. **Project files** — persistent per-project (config/, projects/, context/)
3. **YAML Queue** — persistent task data (queue/ — authoritative source of truth)
4. **Session context** — volatile (CLAUDE.md auto-loaded, instructions/*.md, lost on /clear)

## 4. Token Conservation Techniques

- **slim_yaml.sh/py** — Before each agent reads its queue, a Python script runs with flock to archive completed/read entries. Keeps YAML files small, preventing token bloat. Read messages get archived. Done tasks get archived.
- **Tiered recovery** — After /clear, ashigaru do NOT re-read full instructions (saves ~3,600 tokens). Only read CLAUDE.md (~5,000 tokens) which is auto-loaded. Full instructions read only for 2nd+ tasks.
- **Bloom-based QC routing** — L1-L3 tasks get mechanical QC from Karo (cheap model). Only L4-L6 tasks go to Gunshi (Opus). Prevents Opus token explosion on repetitive work.
- **Batch processing protocol** — For 30+ item batches: execute batch1 only, QC gate, then if OK proceed with remaining batches without per-batch QC.

## 5. Task Decomposition

Karo uses "Five Questions" before assigning tasks:
1. **Purpose** — What does "done" look like? Map to acceptance criteria.
2. **Decomposition** — How to split for maximum parallel efficiency?
3. **Headcount** — How many ashigaru? Split across as many as possible.
4. **Perspective** — What persona/expertise is effective?
5. **Risk** — Race conditions? Dependencies? Availability?

## 6. Parallel Execution Rules

- Independent tasks go to multiple ashigaru simultaneously
- Dependent tasks use `blocked_by` fields in YAML with `pending_blocked` status
- 1 ashigaru = 1 task at a time
- RACE-001 rule: no concurrent writes to the same file by multiple ashigaru
- Karo manages a `pending.yaml` holding area for blocked tasks, releasing them only when dependencies complete

## 7. File-Based Mailbox System

Two-layer architecture:
1. **Message persistence** — `inbox_write.sh` appends to `queue/inbox/{agent}.yaml` using `flock` (exclusive lock) for atomic writes. Messages are structured YAML with id, from, timestamp, type, content, and `read: false`.
2. **Wake-up signal** — `inbox_watcher.sh` uses `inotifywait` (kernel-level file system events, NOT polling) to detect inbox changes, then sends a minimal tmux `send-keys` nudge like `inbox3` (meaning 3 unread).

Message content NEVER travels through tmux — only a short wake-up signal.

## 8. Escalation Protocol

When nudges go unprocessed:
| Elapsed | Action |
|---------|--------|
| 0-2 min | Standard pty nudge |
| 2-4 min | Escape x2 + nudge (cursor position bug workaround) |
| 4 min+ | /clear sent (max once per 5 min) — force session reset |

## 9. Conflict Prevention

- Each ashigaru has dedicated files: `queue/tasks/ashigaru{N}.yaml` and `queue/reports/ashigaru{N}_report.yaml`. No agent reads/writes another agent's files.
- Agent identity from tmux pane metadata `@agent_id`, set at startup.
- Strict forbidden action lists per role.
- Dashboard.md is single-writer (only Karo updates it).

## 10. Redo Protocol

When Karo determines a task needs redo:
1. Write new task YAML with new task_id and `redo_of` field
2. Send `clear_command` type inbox (NOT `task_assigned`)
3. inbox_watcher sends `/clear` to agent — session reset
4. Agent recovers fresh, reads new task YAML

Race condition eliminated: /clear wipes old context before agent sees new task.

## 11. Build System for Generated Instructions

`build_instructions.sh` takes source templates and assembles complete instruction files for each CLI type x role combination. CI enforces generated files stay in sync with sources. Edit in ONE place → all 16 agent instruction files update.

## 12. Multi-CLI Abstraction Layer

`cli_adapter.sh` provides functions: `get_cli_type()`, `build_cli_command()`, `get_agent_model()`, `get_recommended_model()`. Same orchestration works regardless of AI backend.

## 13. Destructive Operation Safety (3 Tiers)

- **Tier 1 ABSOLUTE BAN**: rm -rf /, git push --force, sudo, kill, etc.
- **Tier 2 STOP-AND-REPORT**: deleting >10 files, modifying outside project, unknown URLs
- **Tier 3 SAFE DEFAULTS**: prefer git push --force-with-lease over --force, git stash over git reset --hard

## 14. Quality Check Delegation

| Task Level | QC Method | Gunshi Review? |
|------------|-----------|----------------|
| L1-L2 | Karo mechanical check only | No |
| L3 | Karo mechanical + spot-check | No |
| L4-L5 | Gunshi full review | Yes |
| L6 | Gunshi review + Lord approval | Yes |

For batch tasks (>10 items at same Bloom level), Gunshi reviews ONLY batch 1.

## 15. Purpose Validation

After completing work, ashigaru must re-read the parent command's `purpose` field and verify their deliverable actually achieves it. Any gap is noted under `purpose_gap:` in the report.

## 16. SKIP = FAIL Policy

Any test report with SKIP count >= 1 is considered FAILED. Tests must either run or explicitly fail.

## 17. Skill Candidate Discovery

Every ashigaru report includes mandatory `skill_candidate:` field (found: true/false). When an ashigaru notices a pattern repeated 2+ times, it reports it. Karo collects these.

## 18. North Star Alignment

Every command has a `north_star` field explaining WHY this work matters to the business goal. Gunshi checks at three points: before analysis, during analysis, and in report footer.

## 19. Bloom Taxonomy Model Routing

`capability_tiers` in settings.yaml:
- L1-L3 → Spark (cheapest)
- L4 → Codex 5.3
- L5 → Sonnet Thinking
- L6 → Opus Thinking

Karo assigns `bloom_level` to every task. System recommends cheapest model per task.

## 20. Critical Thinking Rule

1. Verify assumptions, don't take instructions blindly
2. Propose alternatives when a better approach exists
3. Report problems early via inbox
4. Don't over-criticize to the point of paralysis
5. Balance critical thinking with execution speed

## 21. Batch Processing Protocol

```
1. Strategy → Gunshi review → incorporate feedback
2. Execute batch1 ONLY → Shogun QC
3. QC NG → STOP ALL agents → root cause analysis → fix → go to 2
4. QC OK → Execute batch2+ (no per-batch QC needed)
5. All batches complete → Final QC
```

Never skip batch1 QC gate.

## 22. Weaknesses

1. tmux dependency limits to terminal environments
2. Shell-based fragility — no type safety
3. No code-level understanding (no AST, no tree-sitter)
4. No plan stress-testing (no adversarial plan review)
5. No TDD workflow
6. Single Karo bottleneck
7. No diff-aware review (no scan playbooks)
8. Context window limits — slim_yaml is reactive, not preventive
9. Japanese-heavy documentation
10. No code dependency graph for changes

## Sources

- github.com/yohey-w/multi-agent-shogun
- deepwiki.com/yohey-w/multi-agent-shogun
- skillsllm.com/skill/multi-agent-shogun
- sourcepulse.org/projects/23470138
- github.com/torumitsutake/multi-agent-shogun-gui (Community Fork)
