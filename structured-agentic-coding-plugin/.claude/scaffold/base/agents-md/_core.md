# Agent Manifest

> **Auto-generated.** Run `bash .claude/scripts/regenerate-agents-md.sh` to update.

## Policy

All multi-step code changes should go through the masterplan workflow unless the user explicitly specifies otherwise.

## Root Agents (`.claude/agents/`)

### Codebase

| Agent | File | Role |
|-------|------|------|
| Masterplan Architect | `__PREFIX__-masterplan-architect.md` | Designs structured multi-step feature plans through Q&A |
| Masterplan Executor | `__PREFIX__-masterplan-executor.md` | Executes masterplans by dispatching dev/test agents and reviewers |
| Masterplan Reviewer | `__PREFIX__-masterplan-reviewer.md` | Audits completed masterplans for implementation completeness |
| Doc Enforcer | `__PREFIX__-doc-enforcer.md` | Scans for missing/incomplete ARCHITECTURE.md and GUIDELINES.md files |

### Domain

| Agent | File | Role |
|-------|------|------|
| Research | `__PREFIX__-research.md` | Structured feature research — proposals, not code |
| Impact Analyst | `__PREFIX__-impact-analyst.md` | Assesses ripple effects of proposed changes |

## Cross-Cutting Artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| Anti-Patterns | `.claude/anti-patterns.md` | Known failure modes from past executions |
