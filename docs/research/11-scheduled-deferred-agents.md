# Scheduled, Deferred, and Autonomous AI Coding Agents

**Research Date:** 2026-04-13
**Status:** COMPLETE

---

## Table of Contents

1. [Claude Code Native Scheduling](#1-claude-code-native-scheduling)
2. [Cursor Automations](#2-cursor-automations)
3. [GitHub Copilot Coding Agent](#3-github-copilot-coding-agent)
4. [OpenAI Codex App Automations](#4-openai-codex-app-automations)
5. [Devin (Cognition AI)](#5-devin-cognition-ai)
6. [Kiro Autonomous Agent (AWS)](#6-kiro-autonomous-agent-aws)
7. [Claude Managed Agents API](#7-claude-managed-agents-api)
8. [Ralph Wiggum Loop](#8-ralph-wiggum-loop)
9. [Hermes Agent (Nous Research)](#9-hermes-agent-nous-research)
10. [Ductor](#10-ductor)
11. [OpenClaw Cron System](#11-openclaw-cron-system)
12. [ARIS (Auto-Research-In-Sleep)](#12-aris-auto-research-in-sleep)
13. [Community Schedulers](#13-community-schedulers)
14. [Continuous AI on GitHub Actions](#14-continuous-ai-on-github-actions)
15. [Security Scanning Agents](#15-security-scanning-agents)
16. [AI Code Review Agents](#16-ai-code-review-agents)
17. [Technical Debt and Codebase Health](#17-technical-debt-and-codebase-health)
18. [AIOps, Self-Healing, and Incident Response](#18-aiops-self-healing-and-incident-response)
19. [Safety and Governance](#19-safety-and-governance-for-scheduled-agents)
20. [Comparative Analysis](#20-comparative-analysis)
21. [Recommendations for structured-agentic-coding](#21-recommendations-for-structured-agentic-coding)

---

## 1. Claude Code Native Scheduling

Claude Code provides three distinct scheduling mechanisms, from lightweight session-scoped polling to fully cloud-hosted autonomous execution.

### 1a. Cloud Scheduled Tasks (/schedule)

**Released:** March 20, 2026
**Documentation:** code.claude.com/docs/en/web-scheduled-tasks

#### Architecture
- Tasks run on **Anthropic-managed cloud infrastructure** (not your machine)
- Each run clones the GitHub repo fresh from the default branch
- Runs in a configurable **cloud environment** with network access controls, environment variables, and setup scripts
- Each run creates a new session visible alongside other sessions on claude.ai
- No permission prompts -- runs fully autonomously

#### Scheduling Mechanism
- Preset frequencies: **Hourly, Daily, Weekdays, Weekly**
- Custom cron expressions via `/schedule update` (minimum interval: **1 hour**)
- Expressions firing more frequently than hourly (e.g., `*/30 * * * *`) are rejected
- Tasks may run a few minutes after scheduled time (consistent offset per task)
- Time zone aware -- pick time in local zone, infrastructure handles conversion

#### What It Does Autonomously
- Reviews open pull requests each morning
- Analyzes CI failures overnight and surfaces summaries
- Syncs documentation after PRs merge
- Runs dependency audits weekly
- Queries Sentry for top unresolved performance issues, analyzes traces, opens PRs with fixes
- Triages support requests (read Slack, create Linear issues)

#### Repository and Branch Permissions
- Repos cloned from default branch on every run
- By default, Claude can only push to `claude/`-prefixed branches
- "Allow unrestricted branch pushes" can be enabled per repo
- Cannot bypass branch protection rules

#### MCP Connectors
- All connected MCP connectors included by default (Slack, Linear, Google Drive, Sentry, GitHub, etc.)
- Connectors can be added/removed per task
- Connectors give Claude access to external services during each run

#### Creation Methods
- **Web:** claude.ai/code/scheduled
- **Desktop app:** Schedule page, "New remote task"
- **CLI:** `/schedule` (conversational setup) or `/schedule daily PR review at 9am`

#### Management
- `/schedule list` -- see all tasks
- `/schedule update` -- change prompt, schedule, repos, connectors
- `/schedule run` -- trigger immediately
- Pause/resume via toggle
- Each run opens as a full session where you can review, create PRs, or continue conversation

#### Plans and Pricing
- Available on **Pro, Max, Team, and Enterprise** plans
- Uses existing plan's usage allocation
- No separate per-task pricing

#### Limitations
- No access to local files (fresh clone each run)
- Minimum interval: 1 hour
- Cannot run more frequently than hourly
- Dependent on GitHub integration for repo access

### 1b. Desktop Scheduled Tasks

- Runs on **your machine** (requires machine to be on)
- **Persistent across restarts** (survives app close/reopen)
- No open session required
- Has access to local files
- Minimum interval: **1 minute**
- Configurable permission prompts per task
- Managed via Desktop app's Schedule page

### 1c. /loop (Session-Scoped)

- Runs on **your machine** within an active session
- **Dies when you exit** the session
- Minimum interval: **1 minute**
- Inherits MCP servers and permissions from session
- Best for quick polling during active work
- Supports dynamic self-pacing (model chooses delay 60-3600s based on cache TTL)
- ScheduleWakeup mechanism respects Anthropic 5-minute prompt cache TTL

### 1d. Headless Mode (-p flag)

- Accepts prompt directly from command line: `claude -p "your prompt"`
- Executes without user interaction
- Suitable for cron jobs, CI/CD integration, and multi-agent workflows
- Can be wrapped in system schedulers (cron, launchd, Task Scheduler)

### 1e. Remote Control

- REST API + WebSocket stream for real-time output
- Standard API key authentication
- Run Claude Code on server or CI without local terminal
- One orchestrator can dispatch to multiple Claude Code instances in parallel
- Foundation for headless server deployment

#### Sources
- code.claude.com/docs/en/web-scheduled-tasks
- code.claude.com/docs/en/desktop-scheduled-tasks
- code.claude.com/docs/en/scheduled-tasks
- mindstudio.ai/blog/claude-code-headless-mode-autonomous-agents
- computeleap.com/blog/claude-code-remote-tasks-cloud-ai-agents-2026
- mindstudio.ai/blog/claude-code-q1-2026-update-roundup-2
- medium.com/@richardhightower -- "Put Claude on Autopilot" (March 2026)

---

## 2. Cursor Automations

**Launched:** March 5, 2026
**Authors:** Jack Pertschuk, Jon Kaplan, Josh Ma (Cursor)

### Architecture
- Always-on agents that run in **cloud sandboxes**
- When triggered, agent spins up a sandbox, follows instructions using configured MCPs and models, verifies its own output
- **Memory tool** lets agents learn from past runs and improve with repetition
- Agents include decision logging for auditability (e.g., Notion database tracking)

### Trigger Types
- **Schedule-based:** Cron-style (every 2 hours, daily, weekly)
- **Event-driven:** Slack messages, Linear issues, GitHub PR merges/updates, PagerDuty incidents
- **Custom webhooks:** Any internal or external system as trigger source

### What It Does Autonomously
- Audit code diffs for security vulnerabilities
- Classify risk based on blast radius and complexity
- Auto-approve low-risk PRs; assign reviewers for higher-risk changes
- Investigate logs via integrations (Datadog MCP)
- Write and execute tests
- Create fixes and open pull requests
- Deduplicate information across tools
- Generate weekly repository change summaries
- Bug report triage and root cause analysis

### Real-World Use Cases
- **At Cursor:** Security review on every main push, agentic codeowners for risk-based PR routing, PagerDuty incident response, weekly repo summaries, test coverage identification
- **At Rippling:** Personal assistant consolidating meeting notes, PRs, Jira, Slack mentions every 2 hours; handling incident triage, status reports, on-call handoffs
- **At Runlayer:** Software factory scaling -- "move faster than teams five times our size"

### MCP Integration
- Built-in: Datadog, Linear, Notion, Jira, Confluence, GitHub, Slack
- Custom MCP configurations supported
- Webhook event sources

### Safety Mechanisms
- Output verification built into agent workflows
- Decision logging for auditability
- Instructions-based guardrails and constraints
- Configurable approval thresholds (auto-approve vs. assign reviewer)

### Scale
- Cursor estimates **hundreds of automations per hour** running across its platform

### Pricing
- No explicit per-automation pricing disclosed
- Included in Cursor subscription tiers

### Limitations
- Requires explicit MCP configuration for custom integrations
- Depends on instruction quality for reliable outcomes
- Cloud sandbox environment (no local file access)

#### Sources
- cursor.com/blog/automations
- cursor.com/docs/cloud-agent/automations
- techcrunch.com/2026/03/05/cursor-is-rolling-out-a-new-system-for-agentic-coding
- mlq.ai/news/cursor-releases-automations-platform

---

## 3. GitHub Copilot Coding Agent

**GA:** 2026 (announced Microsoft Build 2025, evolved through 2026)

### Architecture
- Runs in **ephemeral GitHub Actions environment** (secure, fully customizable dev environment)
- Spins up on demand when assigned a GitHub issue or prompted in VS Code
- Works in the background -- continues even if your computer is off
- Can work on multiple tasks in parallel

### Scheduling Mechanism
- **Event-driven:** Assign a GitHub issue to `@copilot`, or mention `@copilot` in PR comments
- **CI/CD integration:** Runs as part of GitHub Actions workflows
- No native cron scheduling built-in, but can be triggered by GitHub Actions scheduled workflows

### What It Does Autonomously
- Research repositories and create implementation plans
- Fix bugs and implement incremental features
- Improve test coverage
- Update documentation
- Address technical debt
- Resolve merge conflicts
- **Built-in security scanning:** Runs code scanning, secret scanning, and dependency vulnerability checks before PR opens
- **Self-review:** Reviews its own code before submitting

### Safety Mechanisms
- Cannot bypass rulesets or branch protection rules
- Specific commit author rules can prevent it from creating/updating PRs
- Creates **draft pull requests** for human review
- Reads team's AGENTS.md instruction file before touching source files
- Provisions dedicated branch per task
- Built-in security scanning flags API keys, vulnerable dependencies

### Customization
- Custom instructions (natural-language repository guidelines)
- MCP servers for data sources/tools
- Custom agents for specialized tasks
- Hooks for shell commands at execution points
- Skills for enhanced task performance

### Pricing
- Uses GitHub Actions minutes and Copilot premium requests within existing monthly allowances
- No additional cost beyond Copilot Pro/Pro+/Business/Enterprise plan
- Business/Enterprise admins must enable relevant policies

### Limitations
- Cannot work across multiple repositories in one run
- One branch per task
- Doesn't respect content exclusion configurations
- Only functions with GitHub-hosted repositories
- Cannot bypass certain rulesets

#### Sources
- docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent
- github.blog/news-insights/product-news/github-copilot-meet-the-new-coding-agent
- github.blog/ai-and-ml/github-copilot/whats-new-with-github-copilot-coding-agent
- github.blog/news-insights/product-news/agents-panel-launch-copilot-coding-agent-tasks-anywhere-on-github

---

## 4. OpenAI Codex App Automations

**Platform:** Codex App (macOS, Windows as of March 4, 2026)

### Architecture
- Automations run recurring tasks in the background within the Codex App
- Requires the app to be running
- For Git repos, supports **worktree isolation** (dedicated background worktrees) or local mode
- Non-version-controlled projects run in project directory directly

### Scheduling Mechanism
- Recurring schedule defined via UI form
- Model and reasoning effort settings configurable (defaults available)
- Project selection per automation

### What It Does Autonomously
- Daily issue triage
- Find and summarize CI failures
- Generate daily release briefs
- Check for bugs
- Any recurring development task

### Results Management
- **Inbox system:** Automations add findings to "Triage" inbox section
- Automatically archives if nothing to report
- Users filter by all runs or unread only
- Skills integration via `$skill-name` syntax in prompts

### Safety/Sandbox Model
- **Read-only mode:** Tool calls fail if requiring file modifications, network, or app interactions
- **Workspace-write mode:** Blocks external file access, network, app operations (overridable via rules)
- **Full access mode:** Elevated risk; modifies files and runs commands without prompting
- Uses `approval_policy = "never"` when org policy permits
- Admin-enforced requirements may restrict approval policies

### Worktree Management
- Frequent schedules accumulate worktrees
- Users should archive unused automation runs
- Avoid pinning runs unless intentionally preserving worktrees

### Realtime V2
- Streams background agent progress while work is still running
- Queues follow-up responses until active response completes

### Limitations
- **Requires app to stay running** (not cloud-hosted)
- Sandbox restrictions apply based on security configuration
- Admin-enforced org requirements may limit capabilities

#### Sources
- developers.openai.com/codex/app/automations
- openai.com/index/introducing-the-codex-app
- developers.openai.com/codex/changelog

---

## 5. Devin (Cognition AI)

### Architecture
- Fully autonomous software engineer agent
- Takes tickets from Jira or Slack and delivers pull requests
- Operates in its own development environment with shell, editor, and browser
- Goldman Sachs piloting alongside 12,000 human developers (2026)

### Scheduling Mechanism
- **API for programmatic task assignment** -- integrate into CI/CD pipelines, Slack workflows, custom automation
- Trigger from issue trackers, deploy hooks, or scheduled jobs
- Assign a task before leaving for the day, review PR in the morning

### What It Does Autonomously
- Large migrations and standardized refactoring
- Feature implementation from Jira tickets
- Bug fixes from support tickets
- Code reviews and pull requests
- Overnight autonomous work on assigned tasks

### Safety Mechanisms
- Creates PRs for human review (never auto-merges)
- Session logs available for audit
- Human review required before merge

### Pricing
- Enterprise pricing (not publicly disclosed per-task rates)
- Team and enterprise tiers available

### Limitations
- Best for well-defined tasks (migrations, refactoring, routine features)
- Complex architectural decisions still require human guidance
- No native cron scheduler -- scheduling via API integration

#### Sources
- devin.ai
- docs.devin.ai
- deployhq.com/guides/devin
- vibecoding.app/blog/devin-review
- augmentcode.com/tools/best-devin-alternatives

---

## 6. Kiro Autonomous Agent (AWS)

**Launched:** July 2025 (IDE), December 2025 (autonomous agent at re:Invent), expanding through 2026
**Ownership:** AWS (built on Amazon Bedrock AgentCore, powered by Claude Sonnet 4.5/4.6 and Opus 4.5)

### Architecture
- Built on fork of Code OSS (VS Code base) with proprietary graph-based state engine
- Runs on Amazon Bedrock AgentCore
- Agents execute **asynchronously in the background** -- no active session required
- Can work for **hours or days** without intervention
- Maintains **persistent context across sessions** (doesn't lose memory of task)

### Scheduling Mechanism
- Background execution based on pre-defined prompts
- No explicit cron scheduler documented yet -- tasks are assigned and run continuously
- Integrates with Jira for ticket-driven work
- Agents can be spawned from IDE or API

### What It Does Autonomously
- Research implementation approaches for existing codebases
- Generate documentation, unit tests, optimize code performance
- Plan changes once, create coordinated edits and PRs across multiple repositories
- Learn from user preferences and feedback to shape future changes
- Orchestrate sub-agents for specialized tasks

### Safety Mechanisms
- **Never merges changes automatically** -- creates PRs for review
- Tasks run in **isolated sandbox environments**
- Branch protection recommended for main/production branches

### Multi-Repository Support
- Can coordinate edits across multiple repositories simultaneously
- Creates related PRs that land together

### Integration
- During preview: Jira, Confluence, GitLab, GitHub, Teams, Slack

### Pricing
- **Free during preview** for Kiro Pro, Pro+, and Power users
- Usage subject to weekly limits that reset each week
- Team access invite-only via waitlist

### Limitations
- Currently in limited preview
- Team access restricted to waitlist
- Preview-period weekly limits

#### Sources
- kiro.dev/autonomous-agent
- techcrunch.com/2025/12/02/amazon-previews-3-ai-agents
- constellationr.com insights on Kiro launch

---

## 7. Claude Managed Agents API

**Launched:** April 8, 2026 (public beta)

### Architecture
- Pre-built, configurable agent harness on **Anthropic-managed infrastructure**
- Four core concepts: **Agent** (model + system prompt + tools + MCP + skills), **Environment** (container template), **Session** (running instance), **Events** (messages between app and agent)
- Built-in prompt caching, compaction, and performance optimizations
- Sessions are stateful with persistent file systems and conversation history

### Execution Environment
- Secure cloud containers with pre-installed packages (Python, Node.js, Go, etc.)
- Configurable network access rules
- Mounted files
- Built-in tools: Bash, file operations (read/write/edit/glob/grep), web search/fetch, MCP servers

### How It Works
1. Create an agent (define model, system prompt, tools, MCP servers, skills)
2. Create an environment (configure container, packages, network, files)
3. Start a session (references agent + environment)
4. Send events and stream responses via SSE
5. Steer or interrupt mid-execution

### Multi-Agent Orchestration
- **Agent Teams:** Multiple Claude instances with independent contexts and direct communication
- **Subagents:** Operate in same session, report results to main agent
- Agent Teams suited for complex parallel tasks (higher token cost)
- Features like outcomes, multiagent, and memory in **research preview** (request access)

### Scheduling/Triggering
- No built-in cron -- designed to be triggered by your application code
- Perfect for integration with external schedulers, CI/CD, webhooks
- Long-running sessions (minutes to hours) with multiple tool calls

### Pricing
- **$0.08 per session hour** + standard API Claude token prices
- Available to all Anthropic API accounts in public beta

### Rate Limits
- Create endpoints: 60 requests/minute per org
- Read endpoints: 600 requests/minute per org
- Organization-level spend limits and tier-based rate limits apply

### Limitations
- Beta (behaviors may change)
- No built-in cron -- requires external orchestration
- Session-hour pricing adds up for long-running tasks

#### Sources
- platform.claude.com/docs/en/managed-agents/overview
- platform.claude.com/docs/en/managed-agents/quickstart
- platform.claude.com/docs/en/agent-sdk/overview
- claude.com/blog/claude-managed-agents
- winbuzzer.com/2026/04/10/anthropic-launches-claude-managed-agents-enterprise-ai

---

## 8. Ralph Wiggum Loop

**Origin:** Community technique, now official Anthropic plugin
**Named after:** Ralph Wiggum from The Simpsons (persistent iteration despite setbacks)

### Architecture
- A **Stop hook** intercepts Claude Code's exit and re-feeds the original prompt
- Each iteration sees modified files and git history from previous runs
- Uses `--resume <session_id>` to continue sessions without re-explaining prior work
- Preserves context through session continuity

### Exit Detection: Dual-Condition Gate
Two simultaneous conditions required to exit:
1. **Completion Indicators >= 2** -- heuristic detection from natural language patterns ("all tasks complete", "ready for deployment")
2. **Explicit EXIT_SIGNAL: true** -- Claude must actively confirm readiness via RALPH_STATUS block
- Prevents premature exits during productive iterations

### Safety Mechanisms

#### Three-Layer Rate Limiting
- **Hourly reset:** Default 100 calls/hour (`MAX_CALLS_PER_HOUR`)
- **Token budget:** Optional `MAX_TOKENS_PER_HOUR` (e.g., 500k tokens)
- **5-hour API limit handling:** Three-stage detection (timeout guard, JSON parsing for rate_limit_event, filtered text fallback)

#### Circuit Breaker
- Opens after **3 consecutive loops with no progress** or **5 loops with identical errors**
- Two-stage error filtering eliminates false positives
- Multi-line error matching detects stuck loops
- Configurable: `CB_NO_PROGRESS_THRESHOLD`, `CB_SAME_ERROR_THRESHOLD`

#### Session Expiration
- Default **24-hour timeout** (`SESSION_EXPIRY_HOURS`)
- Automatic session reset after expiration
- Prevents indefinite context accumulation

### Cost
- One Claude Code call uses **100k+ tokens**
- Default 100 calls/hour = ~10M tokens/hour ceiling
- Cost-conscious: Set `MAX_TOKENS_PER_HOUR=500000` (~$5/hour)
- 50-iteration loop on large codebase: **$50-100+**
- YC hackathon teams shipped 6+ repos overnight for **$297 in API costs**
- Geoffrey Huntley ran a **3-month loop** that built a complete programming language

### Best Practices
- Clear PROMPT.md with specific, measurable goals
- Structured fix_plan.md with checkbox tracking
- Tool permissions via .ralphrc (e.g., `Bash(npm *)` only)
- Live monitoring: `ralph --monitor` (tmux dashboard)
- Spec files for complex tasks (`.ralph/specs/`)
- Use `--resume <session_id>` for long-running projects

### Suited For
- Feature implementation, bug fixing, test coverage expansion
- Refactoring, documentation generation, dependency updates
- Batch operations: large refactors, support ticket triage
- Works best when success is **programmatically verifiable** (tests pass, build succeeds)

### Not Suited For
- Tasks requiring external API keys, human decision-making
- Real-time user feedback, complex architectural decisions

### Installation
- Official Anthropic plugin: `/plugin marketplace add anthropics/claude-code` then `/plugin install ralph-wiggum@claude-plugins-official`
- Community version: github.com/frankbria/ralph-claude-code

#### Sources
- github.com/frankbria/ralph-claude-code
- github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/README.md
- paddo.dev/blog/ralph-wiggum-autonomous-loops
- atcyrus.com/stories/ralph-wiggum-technique-claude-code-autonomous-loops
- agentfactory.panaversity.org/docs/General-Agents-Foundations/general-agents/ralph-wiggum-loop

---

## 9. Hermes Agent (Nous Research)

**Released:** February 2026
**Current Version:** v0.8.0 (April 8, 2026)
**License:** MIT (open source, 76,000+ stars)

### Architecture
- **Self-improving AI agent** with closed learning loop
- Lives on your server, remembers what it learns, gets more capable over time
- Agent loop: planning, tool invocation, observation cycles
- 40+ built-in tools (file ops, web browsing, code execution, terminal, APIs)
- MCP integration for extensibility

### Self-Improving Mechanism
1. **Autonomous skill creation:** After complex tasks, agent writes reusable Markdown skill files
2. **Skill self-improvement:** Skills improve during active use
3. **Agent-curated memory:** Periodic nudges to persist knowledge
4. **Cross-session recall:** FTS5 with LLM summarization
5. **User modeling:** Honcho dialectic framework builds deepening profiles across sessions

### Memory Architecture
- Persistent memory via MEMORY.md and USER.md
- Honcho integration for dialectic user modeling
- Session search with LLM summarization
- `/compress` command for context management
- Import support from OpenClaw

### Cron Scheduler
- Built-in scheduler with **natural language task scheduling** (no code required)
- Delivery to any platform (Telegram, Discord, Slack, WhatsApp, Signal, Email, CLI)
- Unattended execution: daily reports, nightly backups, weekly audits
- Per-job timezone support

### Multi-Platform Support
- **Gateway process:** Telegram, Discord, Slack, WhatsApp, Signal, CLI -- all from single process
- Voice memo transcription
- Cross-platform conversation continuity

### Terminal Backends (6 Options)
1. Local execution
2. Docker containerization
3. SSH remote execution
4. Daytona (serverless with hibernation)
5. Singularity containers
6. Modal (serverless with wake-on-demand, "costing nearly nothing between sessions")

### Security Model
- Command approval system with allowlist patterns
- DM pairing for secure platform authentication
- Container isolation for tool execution
- Allowlisted secrets for API keys
- Interrupt capability to stop operations

### Model Flexibility
- Any model via: Nous Portal, OpenRouter (200+ models), z.ai/GLM, Kimi/Moonshot, MiniMax, OpenAI, custom endpoints
- Switch with `hermes model` command

### Migration Path
- `hermes claw migrate` imports from OpenClaw (SOUL.md, memories, skills, API keys, settings)

### Limitations
- Native Windows unsupported (requires WSL2)
- Voice on Termux incompatible with some dependencies
- Context compression required for extended conversations

#### Sources
- github.com/NousResearch/hermes-agent
- hermes-agent.nousresearch.com/docs
- ai.cc/blogs/hermes-agent-2026
- nxcode.io/resources/news/hermes-agent-complete-guide-self-improving-ai-2026

---

## 10. Ductor

**Repository:** github.com/PleasePrompto/ductor

### Architecture
- CLI orchestration platform running official coding CLIs as **subprocesses**
- Supports: **Claude Code, Codex CLI, Gemini CLI**
- All state in plain JSON and Markdown under `~/.ductor/`
- No API proxying, no SDK patching -- just official CLI binaries as subprocesses

### Messenger Integration
- **Telegram (primary):** Live streaming via message edits, inline keyboards, dual allowlist (user IDs + group IDs), forum/topic support for isolated contexts
- **Matrix:** Segment-based output, emoji reaction buttons, E2EE compatible
- Both transports can run simultaneously

### Cron & Automation
- In-process scheduler with **timezone support per job** and global default
- Per-job timezone overrides
- Result routing to originating chat
- Status tracking in `cron_jobs.json`
- Interactive management via `/cron` command

### Webhooks
- **Wake mode:** Inject message into active chat
- **Cron_task mode:** Run as isolated task with result callback
- Defined in `webhooks.json`; requires explicit URL registration

### Context Hierarchy
1. **Single Chat:** Isolated conversation, independent context per provider
2. **Group Topics/Rooms:** Own conversation state, shared workspace
3. **Named Sessions:** Background contexts preserving parent context (`/session <prompt>`)
4. **Background Tasks:** Async work persisted in `tasks.json`, can ask questions back to user
5. **Sub-Agents:** Fully isolated bots with separate workspaces, configs, CLI auth, chat histories

### Memory & Persistence
- Shared memory: `SHAREDMEMORY.md` across all agents
- Per-agent memory: `MAINMEMORY.md` (Markdown format)
- State survives restarts; plain-text format enables version control

### Docker Sandboxing
- Optional sidecar container with configurable host mounts
- Configurable mount points and extra packages
- Rebuild capability
- Runtime isolation for untrusted code

### Security Model
- Telegram: `allowed_user_ids` (required) + `allowed_group_ids`
- Matrix: `allowed_rooms` + `allowed_users` with E2EE
- Hot-reload: Allowlist changes take effect within seconds without restart
- `group_mention_only`: Bot responds only to @mentions in groups

### Service Management
- Linux: systemd
- macOS: launchd
- Windows: Task Scheduler
- Commands: `ductor service install/start/stop/logs`

### Cost
- No Ductor-specific cost; uses existing CLI subscriptions (Claude Max, OpenAI API keys, etc.)
- Local execution -- no intermediate API fees

### Plugin System
- Transport-agnostic: Adding Discord, Slack, Signal requires implementing `BotProtocol`

#### Sources
- github.com/PleasePrompto/ductor
- pypi.org/project/ductor

---

## 11. OpenClaw Cron System

### Architecture
- Cron jobs run through the **Gateway** -- always-on daemon managing scheduling, message routing, and agent lifecycle
- At scheduled time, Gateway triggers agent with fresh session and task context
- Two operating modes:
  - **Heartbeats:** Poll at intervals within main session
  - **Cron jobs:** Run in **isolated sessions** (own context, model, thinking level)

### Key Design Decision
Isolated jobs don't pollute main conversation context. Your scheduled research task won't affect your main chat's context window.

### Persistence
- Jobs persist at `~/.openclaw/cron/jobs.json`
- Restarts don't lose schedules

### Use Cases
- Morning briefings
- Periodic inbox checks
- Daily reports and summaries
- Monitoring and alerting
- Complex multi-step workflows that run while you sleep

### Proactive Agent Pattern (2026 Trend)
Forbes January 2026: "Agentic AI is shifting from assistants into proactive workflow partners." A proactive agent operates on a schedule, identifies what needs attention, and surfaces it without being asked.

#### Sources
- docs.openclaw.ai/automation/cron-jobs
- xcloud.host/proactive-openclaw-agent-workflows
- dev.to/hex_agent/openclaw-cron-jobs-automate-your-ai-agents-daily-tasks

---

## 12. ARIS (Auto-Research-In-Sleep)

**Repository:** github.com/wanshuiyin/Auto-claude-code-research-in-sleep (6,449 stars)
**Full analysis in:** docs/research/03-aris-autonomous-research.md

### Overnight Execution Pipeline
```
/idea-discovery -> IDEA_REPORT.md -> /experiment-bridge -> EXPERIMENT_LOG.md -> /auto-review-loop -> AUTO_REVIEW.md -> /paper-writing -> paper/main.pdf
```

### Key Innovations for Scheduled Execution
1. **Cross-model adversarial review:** Executor and reviewer are different model families (eliminates correlated blind spots)
2. **JSON state persistence:** REVIEW_STATE.json persists after every round; survives context compaction/session recovery
3. **Stale state detection:** If state file >24 hours old, warns before proceeding
4. **Configurable human checkpoints:** `AUTO_PROCEED: true/false` between phases
5. **Effort levels with hard invariants:** Reviewer quality, citation integrity, experiment integrity NEVER change regardless of effort setting
6. **Graceful degradation:** If cross-model review unavailable, falls back and marks `[pending cross-model review]`
7. **Failed approach memory:** Dead ends tracked as first-class artifacts, never pruned, preventing re-exploration

### Relevance to Scheduled Agents
ARIS demonstrates the most sophisticated overnight autonomous pipeline pattern: start before bed, review results in morning. Its state persistence, stale detection, and checkpoint system are directly applicable to any scheduled agent architecture.

---

## 13. Community Schedulers

### 13a. jshchnz/claude-code-scheduler

**Repository:** github.com/jshchnz/claude-code-scheduler

- **Plugin for Claude Code** that puts Claude on autopilot
- Uses **native OS schedulers:** launchd (macOS), crontab (Linux), Task Scheduler (Windows)
- **Natural language scheduling:** "every weekday at 9am review yesterday's code", "today at 3pm remind me to deploy"
- Generates shell script wrapper that calls Claude Code with prompt as input
- Registers wrapper with cron at specified interval
- Bridges Claude Code and OS scheduling -- truly autonomous, unattended execution without app running
- Requires Claude Code v1.0.33+
- Install: `/plugin marketplace add jshchnz/claude-code-scheduler`

### 13b. tonybentley/claude-mcp-scheduler

**Repository:** github.com/tonybentley/claude-mcp-scheduler

- Uses **Claude API** to prompt remote agents on cron intervals
- Local **MCP servers handle tool calls** for context (e.g., filesystem MCP)
- Extensible: add MCP servers for databases, APIs, custom tools
- Config: schedules defined by name, cron expression, enabled status, prompt, output path
- Runs on headless servers/VMs/containers without GUI
- Parallel processing of multiple scheduled tasks
- Cost optimization: only pay for API usage when tasks run

### 13c. PhialsBasement/scheduler-mcp

- MCP server that lets you schedule **shell commands, API calls, AI tasks, and desktop notifications** using cron expressions
- Built with Model Context Protocol for integration with Claude Desktop and other AI assistants

### 13d. Continuous Claude (AnandChowdhary/continuous-claude)

- Automated workflow orchestrating Claude Code in continuous loop
- Creates PRs incrementally
- Listed in GitHub's awesome-continuous-ai repository

#### Sources
- github.com/jshchnz/claude-code-scheduler
- github.com/tonybentley/claude-mcp-scheduler
- github.com/PhialsBasement/scheduler-mcp
- github.com/AnandChowdhary/continuous-claude

---

## 14. Continuous AI on GitHub Actions

The **awesome-continuous-ai** repository (github.com/githubnext/awesome-continuous-ai) catalogs the emerging ecosystem of AI agents running continuously in CI/CD.

### Categories and Key Tools

#### Continuous Triage
- **Ultralytics Actions:** AI labeling and summarization
- **Automattic Issue Triage:** Automatic issue labeling for Jetpack
- **Dosu:** Automated GitHub issue triage
- **Continuous AI Resolver:** Automatically resolve stale/already-fixed issues and PRs using AI
- **GitHub Test Reporter:** AI analyses of test results, flaky test detection

#### Continuous Documentation
- **Penify.dev:** Instantly generates and updates repository documentation
- **DeepWiki:** Auto-generates architecture diagrams, docs, links to source
- **cADR (Continuous Architectural Decision Records):** AI-powered ADR generation
- **docAider:** Multi-agent code documentation generation and review

#### Continuous Code Review
- **GitHub Copilot Code Review:** Request reviews from Copilot
- **CodeRabbit:** Advanced AI code reviews (2M+ repos, 13M+ PRs reviewed)
- **Gemini Code Assist:** Google's code review integration
- **Shippie:** Code review, secrets detection, bug fixes (TypeScript + Bun)

#### Continuous Code Optimization
- **CatchMetrics:** RUM web performance data via MCP to AI agents
- **CodeFlash:** Finds fastest Python code versions through benchmarking

#### Continuous Test Improvement
- **SoftwareTesting AI:** Coverage gap identification
- **DiffBlue:** Automated continuous unit testing at scale in CI

#### Agentic Frameworks for CI
- **Copilot Coding Agent:** Works on issues, raises PRs
- **Claude Code GitHub Actions:** Claude in CI pipeline
- **Amazon Q Developer:** AI code assistant across SDLC
- **Continue:** Framework for custom agents across IDE, terminal, CI
- **GitHub Agentic Workflows (gh-aw):** Framework for AI-powered agentic workflows

### Security Warning
- **hackerbot-claw incident (Feb-March 2026):** Autonomous bot systematically scanned public repos for exploitable GitHub Actions workflows, successfully exfiltrated tokens
- Lesson: "You cannot defend against automation with manual controls -- you need automated guardrails"

### Cost Warning
- One developer reported **$1,800 in charges** after a workflow inherited `ANTHROPIC_API_KEY` from shell
- Rule of thumb: if you set `ANTHROPIC_API_KEY`, assume the meter is running

#### Sources
- github.com/githubnext/awesome-continuous-ai
- kissapi.ai/blog/claude-code-github-actions-setup-guide-2026
- stepsecurity.io/blog/hackerbot-claw-github-actions-exploitation

---

## 15. Security Scanning Agents

### 15a. Snyk Agent Scan

**Repository:** github.com/snyk/agent-scan

#### What It Scans
- **MCP Servers:** Prompt injection, tool poisoning, tool shadowing, toxic flows
- **Agent Skills:** Prompt injection, malware payloads, untrusted content, credential handling, hardcoded secrets
- **Agent Configurations:** Claude, Cursor, Windsurf, Gemini CLI, OpenClaw, Kiro, Antigravity, Codex, Amazon Q

#### 15+ Distinct Security Risks Detected
- Prompt injections in tool descriptions
- Tool poisoning and shadowing attacks
- Toxic information flows between components
- Malware payloads in skill descriptions
- Credential mishandling patterns
- Exposed secrets in configurations

#### Operating Modes
- **Scan Mode:** One-time CLI execution with comprehensive security report
- **Background Mode:** Continuous monitoring for enterprise deployment (MDM/CrowdStrike integration), reporting to Snyk Evo dashboard

#### Installation
```
uvx snyk-agent-scan@latest
```
Requires `SNYK_TOKEN` environment variable.

#### Snyk Evo AI-SPM (March 2026)
- **Discovery Agent:** Maps attack surface, generates live AI Bill of Materials
- **Risk Intelligence Agent:** Enriches inventory with metadata, hallucination/bias metrics, security signals
- **Mission Control Integration:** Continuous AI -- agents autonomously detect, analyze, fix vulnerabilities, generate PRs

### 15b. Semgrep (2026)

- **Multimodal AppSec engine:** Combines deterministic analysis with LLM reasoning
- Zero false positives on deterministic rules, deep context-aware detection
- Available as **Cursor and Claude Code plugin** for automatic scanning
- **MCP server** for integration into agentic workflows
- CI/CD integration for continuous automated scanning
- **Semgrep Multimodal** (formerly Semgrep Assistant): AI-powered triage and remediation
- Detects complex business logic flaws (IDORs, broken authorization)

### 15c. SonarQube Agentic Analysis (March 2026)

- **MCP server integration:** Agent "asks" SonarQube to check its own generated code in real time
- Applies existing quality profiles automatically to AI-generated code
- Catches security risks and logic errors before human review
- Open beta for SonarQube Cloud Teams and Enterprise
- Automatically scans all branches, PRs, merges on commit/push

### 15d. Dependabot + AI Agents (April 2026)

- **Dependabot alerts now assignable to AI agents** (Copilot, Claude, Codex) for remediation
- Agent analyzes advisory + dependency usage, opens draft PR with proposed fix
- Attempts to resolve test failures introduced by update
- Scheduled scanning: govulncheck as GitHub Action on push, PR, or daily cron
- Version updates: PRs for new releases on configurable schedule (daily, weekly, monthly)
- **Caveat:** AI-generated fixes not always correct -- always review before merge

### 15e. Maze (Vulnerability Management)

- **$30.6M funded** (Series A, June 2025), 10+ enterprises including 2 Fortune 200
- AI agents replicate expert security engineer investigation autonomously at scale
- Investigates each vulnerability in context, removes false positives
- **80-90% of findings proven false positives** when investigated in context
- One-click remediation for critical vulnerabilities
- Intelligent workflows prepare immediate mitigations

### 15f. Microsoft Agent Governance Toolkit (April 2026)

- Open-source runtime security governance for autonomous AI agents
- **First toolkit to address all 10 OWASP agentic AI risks**
- Deterministic, **sub-millisecond** policy enforcement
- Sandboxing, guardrails, monitoring, auditing stack

#### Sources
- github.com/snyk/agent-scan
- securityboulevard.com/2026/03/snyk-launches-agent-security-solution
- semgrep.dev/blog/2025/what-a-hackathon-reveals-about-ai-agent-trends-to-expect-2026
- sonarsource.com/blog/agentic-analysis-beta
- github.blog/changelog/2026-04-07-dependabot-alerts-are-now-assignable-to-ai-agents
- mazehq.com/blog/launching-maze
- opensource.microsoft.com/blog/2026/04/02/introducing-the-agent-governance-toolkit

---

## 16. AI Code Review Agents

### 16a. CodeRabbit (2026)

- **Most widely deployed** dedicated AI code review tool: 2M+ repos, 13M+ PRs reviewed
- Automatically reviews every PR on GitHub, GitLab, Azure DevOps, Bitbucket
- Continuous incremental reviews for each commit within a PR
- 40+ linters and security scanners integrated, filters false positives
- Reviews improve continuously from natural language feedback
- **Issue Planner (Feb 2026):** Auto-generates Coding Plans from Linear/Jira/GitHub Issues referencing relevant codebase files -- helps AI coding agents get precise specifications

### 16b. Qodo (formerly CodiumAI)

- **Qodo 2.0 (Feb 2026):** Multi-agent review architecture, highest F1 score (60.1%) in benchmarks
- **Qodo Cover:** Fully autonomous regression testing agent
  - Generates tests by analyzing source code
  - Validates each test: runs successfully, passes, increases coverage
  - Only keeps tests meeting all criteria
  - Deployable as GitHub Action (auto-creates PRs with tests for changed code) or full repo analyzer
  - Supports 12+ languages, multiple AI models (Claude 3.5 Sonnet, GPT-4o)

### 16c. Augment Code

- **Remote Agents** for background execution
- **Context Engine:** Semantic indexing and dependency graphs for living codebase map
- **Intent workspace:** Desktop workspace for multi-agent orchestration centered on living spec
- Auggie CLI: Plain language goals, agent executes across files
- Cross-service relationship awareness
- No background scheduling documented -- async task execution but no cron

### 16d. Windsurf (Codeium/Cognition AI)

- Acquired by Cognition AI (Dec 2025, ~$250M)
- Cascade AI engine: Multi-step autonomous actions, multi-file changes, terminal commands
- #1 in LogRocket AI Dev Tool Power Rankings (Feb 2026)
- **No background or async agent mode** -- requires pairing with separate background platform for scheduled work

#### Sources
- coderabbit.ai
- qodo.ai
- augmentcode.com
- windsurf.com

---

## 17. Technical Debt and Codebase Health

### 17a. CodeScene

- **CodeHealth** metric validated by actual engineering outcomes
- Behavioral code analysis: how teams interact with code, not just static patterns
- Automated PR code health reviews as quality gate
- Continuous monitoring dashboard tracking trends over time
- Predicts which tech debt will cause delivery problems
- Integrates with CI/CD as automated quality gate

### 17b. Codegen

- Forward-deployed team of AI agents for codebase management
- Agents analyze codebase, implement fixes, surface PRs
- Complex refactoring and task planning
- 8 AI tools for technical debt management

### 17c. Byteable

- Autonomous refactoring inside CI/CD
- GitHub Actions-style automation for refactoring and compliance
- Governance-heavy team focus
- Structured outputs for audit trails

### 17d. Teamscale

- Maps entire code ecosystem: architecture flaws, test gaps, compliance risks
- Comprehensive technical debt analysis

### Key Statistics (2026)
- **40% quality deficit:** Gap between code generated and code properly reviewed widening each quarter
- **80-100% of AI-generated code** contains at least one of 10 recurring anti-patterns (Ox Security 2025)
- **4x maintenance costs** for unmanaged AI-generated code
- **75% of tech leaders** projected impacted by high technical debt by 2026
- **IBM:** Strategic tech debt management increases AI ROI by up to 29%
- **60-80% technical debt reduction** possible through AI tools

#### Sources
- codescene.com
- codegen.com/blog/ai-tools-for-technical-debt
- byteable.ai
- infoq.com/news/2025/11/ai-code-technical-debt
- codebridge.tech/articles/the-hidden-costs-of-ai-generated-software

---

## 18. AIOps, Self-Healing, and Incident Response

### Market Context
- Agentic AI market: **$7.3B (2025) -> projected $139B (2034)** at 40%+ CAGR
- Gartner: By 2026, **50% of large enterprises** will integrate AIOps
- Gartner: By 2026, **60%+ of large enterprises** will have self-healing systems powered by AIOps
- Reality check: **72-79% test/deploy, only 1 in 9 runs in production**

### 18a. PagerDuty (Spring 2026 Release)

- **Agent Builder Incident Responder template** on PagerDuty MCP server
- Under set policies, agents handle detection, triage, remediation autonomously
- **SRE Agent:** Integrations from observability (Datadog) + knowledge bases (Confluence), agentic triage, automated diagnostics, governed remediation
- Automation-first path to self-healing: executes approved remediations, verifies outcomes
- **30+ AI partners** across 11 categories in integration ecosystem
- Communication with AWS DevOps Agent, Azure SRE for cross-cloud remediation

### 18b. AWS DevOps Agent (GA 2026)

- Autonomous incident response for AWS infrastructure
- Leverages agentic AI for detection -> diagnosis -> remediation
- Native PagerDuty integration for operational context
- Self-healing with automated rollbacks and scaling

### 18c. Agentic SRE Pattern

The emerging "Agentic SRE" pattern combines:
1. Telemetry ingestion (metrics, logs, traces)
2. Reasoning (root cause analysis, impact assessment)
3. Controlled automation (pod restarts, config rollbacks, scaling adjustments)
4. Verification (confirm remediation worked)
5. Learning (improve future responses)

Closed-loop pipeline with minimal human intervention.

### 18d. Self-Healing Data Pipelines

- Biggest trend data scientists can't ignore in 2026
- AI agents monitor pipeline health, detect anomalies, auto-remediate
- Schema drift detection and automatic adaptation
- Dependency failure recovery

#### Sources
- unite.ai/agentic-sre-how-self-healing-infrastructure-is-redefining-enterprise-aiops
- pagerduty.com/blog/ai/we-built-an-sre-agent-with-memory
- aws.amazon.com/blogs/devops/leverage-agentic-ai-for-autonomous-incident-response
- cloudmagazin.com/en/2026/04/04/agentic-ai-cloud-autonomous-workflows-devops-2026
- ennetix.com/the-rise-of-autonomous-it-operations-what-aiops-platforms-must-enable-by-2026

---

## 19. Safety and Governance for Scheduled Agents

### OWASP Top 10 for Agentic Applications (December 2025)

First formal taxonomy of risks for autonomous AI agents, developed by 100+ experts:

| ID | Risk | Description |
|----|------|-------------|
| ASI01 | Agent Goal Hijack | Hidden prompts turn agents into exfiltration engines |
| ASI02 | Tool Misuse | Agents bend legitimate tools into destructive outputs |
| ASI03 | Identity & Privilege Abuse | Leaked credentials let agents operate beyond scope |
| ASI04 | Insufficient Sandboxing | Agent escapes isolation |
| ASI05 | Data Exfiltration | Agent leaks sensitive data |
| ASI06 | Unsafe Output Handling | Agent output used without validation |
| ASI07 | Missing Monitoring | No observability into agent decisions |
| ASI08 | Supply Chain Attacks | Compromised tools/skills |
| ASI09 | Human-Agent Trust Exploitation | Agent manipulates human trust |
| ASI10 | Rogue Agents | Agent operates independently of intended purpose |

### Regulatory Landscape
- **EU AI Act** high-risk obligations: August 2026
- **Colorado AI Act:** June 2026
- **OWASP Agentic Skills Top 10:** Separate project for skill-level security

### Best Practices for Scheduled Autonomous Agents

#### Execution Isolation
- Non-root containers with network egress filtering
- Read-only mounts for source code
- **Strict timeouts on every agent task**
- Purpose-built AI sandboxes (E2B market leader, Alibaba OpenSandbox for enterprise)

#### Credential Management
- **Short-lived, dynamically issued credentials** scoped to individual tasks
- Traditional rotation breaks multi-hour agent workflows
- Never store long-lived credentials in agent environment

#### Guardrail Architecture
- **Identity/access control** layer
- **Behavioral boundaries** layer
- **Visibility/observability** layer
- Start agents in **shadow mode** (analyze but don't act)
- Sandbox in isolated accounts
- Test in staging before production

#### Monitoring and Audit
- Log every tool invocation with input/output
- Decision logging for compliance
- Alert on anomalous behavior patterns
- Kill switch for runaway agents

#### Emerging Tools
- **Microsoft Agent Governance Toolkit:** Open-source, covers all 10 OWASP risks, sub-millisecond enforcement
- **DashClaw:** Intercepts and authorizes agent actions pre-execution
- **agent-control:** Fine-grained permission policies
- **Guardrails-ai:** Guards LLM outputs (not agent actions)

### Supply Chain Reality
- Audit of 2,890+ OpenClaw skills: **41.7% contain serious security vulnerabilities**
- Skills ecosystem has systemic risk -- every scheduled agent using skills inherits this exposure

#### Sources
- genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026
- github.com/microsoft/agent-governance-toolkit
- northflank.com/blog/best-code-execution-sandbox-for-ai-agents
- iain.so/security-for-production-ai-agents-in-2026
- phasetransitionsai.substack.com/p/agent-governance-in-2026
- blog.cyberdesserts.com/ai-agent-security-risks
- firecrawl.dev/blog/ai-agent-sandbox

---

## 20. Comparative Analysis

### Scheduling Capability Matrix

| Solution | Scheduling | Runs Where | Needs Machine On | Cron Support | Event Triggers | MCP/Tools | Multi-Repo | Auto-PR |
|----------|-----------|------------|-------------------|--------------|----------------|-----------|------------|---------|
| Claude Code /schedule | Native cron | Anthropic cloud | No | Yes (1h min) | No | MCP connectors | Per-run (single clone) | Yes |
| Claude Code Desktop | Native intervals | Local machine | Yes | Via interval | No | Config files | Yes (local) | N/A |
| Claude Code /loop | Session-scoped | Local machine | Yes (session) | Dynamic | No | Session MCPs | Yes (local) | N/A |
| Cursor Automations | Cron + events | Cloud sandbox | No | Yes | Slack, Linear, GitHub, PagerDuty, webhooks | Built-in + custom MCPs | Single | Yes |
| Copilot Coding Agent | Event-driven | GitHub Actions | No | Via GH Actions cron | Issue assign, PR comment | MCP servers | No | Yes |
| Codex Automations | Recurring schedule | Local (app required) | Yes | Yes | No | Skills | Single | Via worktree |
| Devin | API-driven | Devin cloud | No | Via external integration | Jira, Slack triggers | Built-in | Single | Yes |
| Kiro Autonomous | Task assignment | AWS cloud | No | No (continuous) | Jira | Built-in | Yes (multi-repo) | Yes |
| Managed Agents API | External trigger | Anthropic cloud | No | Via external orchestrator | Any (API-driven) | MCP + built-in | Per session | Via agent |
| Ralph Wiggum | Continuous loop | Local machine | Yes | No (loop) | No | Session | Single | Yes |
| Hermes Agent | Natural language cron | User server | Yes (daemon) | Yes | Platform messages | MCP + 40 tools | Single | N/A |
| Ductor | In-process cron | User machine | Yes (daemon) | Yes | Webhooks, messages | CLI-native | Per CLI | N/A |
| OpenClaw | Gateway cron | User machine | Yes (daemon) | Yes | No | Skills | Single | N/A |
| jshchnz scheduler | OS-native cron | Local machine | Yes | Yes (native OS) | No | Session | Single | N/A |
| claude-mcp-scheduler | API + cron | Any server | Yes | Yes | No | Local MCPs | Single | N/A |

### Safety Mechanism Comparison

| Solution | Sandboxing | Branch Protection | Auto-Merge Prevention | Rate Limiting | Circuit Breaker | Human Checkpoint |
|----------|-----------|-------------------|----------------------|---------------|-----------------|-----------------|
| Claude Code /schedule | Cloud container | claude/ prefix only | Never auto-merges | Plan limits | No | Via session review |
| Cursor Automations | Cloud sandbox | Configurable | Risk-based routing | Plan limits | No | Approval thresholds |
| Copilot Agent | GH Actions runner | Respects rulesets | Draft PRs | Premium requests | No | Draft PR review |
| Codex Automations | Read-only/workspace-write/full | Worktree isolation | No auto-merge | Org policies | No | Approval policy |
| Devin | Own environment | PR-based | Never auto-merges | API limits | No | PR review |
| Kiro | Isolated sandbox | Recommended | Never auto-merges | Weekly limits | No | PR review |
| Ralph Wiggum | None (local) | None | N/A | 3-layer rate limit | Yes (3 no-progress / 5 same-error) | EXIT_SIGNAL gate |
| Hermes Agent | Docker/Singularity/Modal | N/A | N/A | Provider limits | No | Command allowlist |
| Ductor | Optional Docker | N/A | N/A | Provider limits | No | User allowlists |

### Cost Comparison

| Solution | Pricing Model | Estimated Cost for Overnight Run |
|----------|--------------|----------------------------------|
| Claude Code /schedule | Included in Pro/Max/Team/Enterprise plan | Plan usage allocation |
| Cursor Automations | Included in subscription | Subscription |
| Copilot Agent | GH Actions minutes + Copilot premium requests | Existing plan |
| Codex Automations | Included in Codex app | Existing plan |
| Devin | Enterprise pricing | Not publicly disclosed |
| Kiro | Free during preview (weekly limits) | Free (preview) |
| Managed Agents API | $0.08/session-hour + token costs | ~$5-20 for 8-hour run |
| Ralph Wiggum | API token costs | $50-100+ (50 iterations, large codebase) |
| Hermes Agent | Provider API costs | Varies by model/provider |
| Ductor | CLI subscription costs | Existing CLI plans |

---

## 21. Recommendations for structured-agentic-coding

### High Priority

#### R1: /schedule Integration for Overnight Masterplan Execution
- Run masterplan-architect overnight via `/schedule` on Anthropic cloud
- Prompt: "Read MASTERPLAN.md, execute next pending phase, update status, push results to claude/ branch"
- Developer reviews architect output in morning, approves or redirects
- **Safety:** claude/ branch prefix prevents accidental main corruption

#### R2: Scheduled Scan Playbook Execution
- Configure weekly/nightly security and quality scans via `/schedule`
- Connect Sentry MCP for production error triage
- Connect SonarQube MCP for code health monitoring
- Connect Semgrep for security scanning
- Results surfaced as sessions reviewable on claude.ai

#### R3: ARIS-Style State Persistence for Long-Running Tasks
- Implement JSON state files (like REVIEW_STATE.json) for masterplan execution
- Stale state detection (>24h warning)
- Compact recovery protocol when context is limited
- Failed approach memory to prevent re-exploring dead ends

#### R4: Cross-Model Adversarial Review on Schedule
- Use Managed Agents API to run nightly review with different model family
- Executor (Claude) work reviewed by different model (via MCP or Agent Teams)
- Eliminates correlated blind spots in AI-generated code

### Medium Priority

#### R5: Cursor Automations-Style Event Triggers
- On PR merge: run scan playbooks against changed files
- On Sentry alert: auto-investigate, propose fix
- On Linear issue creation: generate implementation plan
- Requires webhook integration (not yet native in claude-code-scheduler)

#### R6: Ralph Wiggum Circuit Breaker Pattern
- Adopt 3-no-progress / 5-same-error circuit breaker for executor loops
- Session expiration timeout for long-running subagents
- Rate limiting awareness in executor subagent prompts

#### R7: Continuous AI GitHub Actions Integration
- Claude Code GitHub Actions for automated PR review on every push
- Semgrep + SonarQube scans in pipeline
- Dependabot alerts auto-assigned to Copilot/Claude for remediation
- Test reporter with AI analysis of failures

#### R8: Proactive Codebase Health Reports
- Weekly scheduled agent that:
  1. Runs all scan playbooks
  2. Checks test coverage trends
  3. Analyzes technical debt metrics
  4. Generates CODEBASE_HEALTH.md report
  5. Creates issues for degraded areas

### Lower Priority / Future

#### R9: Hermes-Style Self-Improving Skills
- After masterplan completion, agent writes reusable skill from experience
- Skills improve during use
- Failed approaches tracked as anti-patterns

#### R10: OpenClaw-Style Isolated Sessions for Scheduled Tasks
- Scheduled tasks get their own context window (don't pollute developer's main session)
- Fresh context = better performance on complex analysis

#### R11: Multi-Platform Notification (Ductor Pattern)
- Scheduled task results delivered to Telegram/Slack/Teams
- Developer reviews on phone, approves/redirects from mobile
- Morning briefing pattern

---

## Academic and Industry References

### Proactive AI Research
- **CHI 2025:** "Assistance or Disruption? Exploring and Evaluating the Design and Trade-offs of Proactive AI Programming Support" (dl.acm.org/doi/10.1145/3706598.3713357)
- **Anthropic 2026 Agentic Coding Trends Report:** resources.anthropic.com/hubfs/2026%20Agentic%20Coding%20Trends%20Report.pdf
- **arxiv.org/html/2508.11126v2:** "AI Agentic Programming: A Survey of Techniques, Challenges, and Opportunities"
- **Self-Improving Coding Agent (Bristol, 2025):** arxiv.org/html/2504.15228v1 -- 17% -> 53% on SWE-Bench by editing own prompts
- **Meta-Harness (Stanford, 2026):** arxiv.org/abs/2603.28052 -- Harness design matters as much as model weights
- **Darwin Godel Machine (Sakana AI):** Agent that modifies its own codebase to self-improve
- **Karpathy AutoResearch:** 630 lines, one GPU, 700 experiments in 2 days

### Industry Reports
- **GitClear:** 8x increase in duplicated code from AI, refactoring dropped 25% -> <10%
- **Ox Security:** 10 recurring anti-patterns in 80-100% of AI-generated code
- **Gartner:** 50% of large enterprises integrating AIOps by 2026; 60%+ self-healing by 2026
- **Forbes (Jan 2026):** Agentic AI shifting from assistants to proactive workflow partners
- **OpenClaw Audit:** 41.7% of skills contain serious security vulnerabilities
