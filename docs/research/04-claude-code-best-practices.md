# Claude Code Best Practices: Techniques for AI Coding Systems

**Research Date:** 2026-04-13
**Source:** github.com/shanraisshan/claude-code-best-practice (148k stars, updated Apr 12 2026)

---

## 1. Code Indexing and Navigation

**"Agentic search (glob + grep) beats RAG"** — Boris Cherny (Claude Code creator) explicitly states Claude Code **tried and discarded vector databases** because "code drifts out of sync and permissions are complex." Current approach: glob + grep.

**Built-in Explore agent** — Read-only agent using Haiku optimized for "finding files, searching code, and answering codebase questions." Uses Read-only tools (no Write, Edit).

## 2. Context Management and Token Optimization

**CLAUDE.md under 200 lines per file.** Longer files get ignored. Wrap critical domain rules in `<important if="...">` tags.

**Lazy/descendant loading for monorepos.** CLAUDE.md in subdirectories load only when Claude reads files in those directories. Don't load irrelevant context upfront.

**Skill descriptions vs full content.** Descriptions loaded at startup (up to 15,000 char budget `SLASH_COMMAND_TOOL_CHAR_BUDGET`). Full content only on invocation. Progressive disclosure.

**Tool Search / deferred tool loading.** When MCP tool definitions exceed 10% of context, auto-deferred and discovered via MCPSearch.

**Programmatic Tool Calling (PTC)** — ~37% token reduction. Claude writes Python that orchestrates multiple tool calls in one inference pass. Only stdout enters context window. Intermediate results never reach the model.

**Dynamic Filtering** — 24% fewer input tokens by having Claude write filtering code before results enter context.

**Manual /compact at max 50% context.** Performance degrades as context fills ("agent dumb zone"). Compact proactively.

## 3. Fresh Context Windows and Wave Execution

**GSD workflow** — fresh 200K contexts + wave execution. Each execution wave gets completely fresh context window with only plan and relevant context.

**Core pattern across all workflows:** Research → Plan → Execute → Review → Ship. Plan in one session, execute in fresh session.

**Boris's technique:** "Start with minimal spec, ask Claude to interview you using AskUserQuestion, then make a new session to execute the spec."

**Subagents = throw more compute.** Each gets own context window. "Separate context windows make results better; one agent can cause bugs and another (same model) can find them."

## 4. Project Structure Discovery

**No explicit structural awareness mechanism exists.** Agents discover structure through Glob, Grep, file reading, CLAUDE.md files. This is the gap a code graph fills.

**Hooks for dynamic context loading.** SessionStart hook can dynamically load context each session start.

**`--add-dir` for multi-repo awareness.** Claude accesses multiple repositories.

**ASCII diagrams for architecture.** Boris recommends "use ASCII diagrams a lot to understand your architecture."

## 5. Agent Orchestration Patterns

**Command → Agent → Skill architecture:**
- Command = user-triggered entry point
- Agent = autonomous actor in isolated context
- Skill = reusable procedure

**Agent resolution order:** Skill (inline, no overhead) > Agent (separate context) > Command (only if explicit). Lightest-weight option wins.

**Agent memory scopes:**
- `user` scope: `~/.claude/agent-memory/` — cross-project
- `project` scope: `.claude/agent-memory/` — team-shared, version controlled
- `local` scope: `.claude/agent-memory-local/` — personal, git-ignored
- First 200 lines of MEMORY.md injected at startup

**Skills as folders with progressive disclosure.** Use references/, scripts/, examples/ subdirectories.

**9 skill categories (Thariq at Anthropic):**
1. Library & API Reference
2. Product Verification
3. Data Fetching & Analysis
4. Business Process & Team Automation
5. Code Scaffolding & Templates
6. Code Quality & Review
7. CI/CD & Deployment
8. Runbooks
9. Infrastructure Operations

**Skill description is a trigger, not a summary.** Write for the model: "when should I fire?" not "what do I do."

**Gotchas section is highest-signal content.** Build up from common failure points.

**`context: fork` for skill isolation.** Runs in isolated subagent.

**Dynamic shell output in skills.** `` !`command` `` runs shell commands on invocation.

## 6. Parallel Execution Patterns

**5+ Claudes in parallel** is Boris's daily workflow. Numbers tabs 1-5, uses system notifications.

**Git worktrees for isolation.** `claude -w` starts session in worktree. Each agent gets own working copy.

**Agent teams with tmux.** Multiple agents working in parallel on same codebase.

**`/batch` for massive changesets.** Fans out to as many worktree agents as needed.

**Cross-model workflow.** Claude Code (Opus) writes plan → Codex CLI (GPT-5.4) reviews → Claude implements → Codex verifies.

## 7. Token Optimization Specifics

**`--bare` flag: up to 10x faster.** Skips CLAUDE.md, settings, MCP discovery.

**Tool Search Tool: ~85% reduction** in tool definition tokens (77K → 8.7K). Mark infrequent tools `defer_loading: true`.

**PTC: ~37% token reduction.** Tool results from programmatic calls NOT added to context.

**Effort levels.** low/medium/high/max. Boris uses high for everything.

**Opus for planning, Sonnet for code.** Different models for different phases.

## 8. Verification and Feedback Loops

**"Give Claude a way to verify its work" — single most important tip.** Boris: "If Claude has that feedback loop, it will 2-3x the quality."

**Product verification skills** worth "having an engineer spend a week just making them excellent."

**PostToolUse hook for auto-formatting.** Claude generates well-formatted code; hook handles last 10%.

**Stop hook for continuation.** Nudge Claude to keep going or verify at end of turn.

## Sources

- github.com/shanraisshan/claude-code-best-practice
- Boris Cherny (Claude Code creator) quotes throughout
- Thariq at Anthropic (skill categories)
