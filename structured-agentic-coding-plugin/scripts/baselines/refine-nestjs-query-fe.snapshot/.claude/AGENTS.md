# Agent Manifest

> **Auto-generated.** Run `bash .claude/scripts/regenerate-agents-md.sh` to update.

## Policy

All multi-step code changes should go through the masterplan workflow unless the user explicitly specifies otherwise.

## Root Agents (`.claude/agents/`)

### Codebase

| Agent | File | Role |
|-------|------|------|
| Masterplan Architect | `testrnq-masterplan-architect.md` | Designs structured multi-step feature plans through Q&A |
| Masterplan Executor | `testrnq-masterplan-executor.md` | Executes masterplans by dispatching dev/test agents and reviewers |
| Masterplan Reviewer | `testrnq-masterplan-reviewer.md` | Audits completed masterplans for implementation completeness |
| Doc Enforcer | `testrnq-doc-enforcer.md` | Scans for missing/incomplete ARCHITECTURE.md and GUIDELINES.md files |

### Domain

| Agent | File | Role |
|-------|------|------|
| Research | `testrnq-research.md` | Structured feature research — proposals, not code |
| Impact Analyst | `testrnq-impact-analyst.md` | Assesses ripple effects of proposed changes |

## Cross-Cutting Artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| Anti-Patterns | `.claude/anti-patterns.md` | Known failure modes from past executions |
