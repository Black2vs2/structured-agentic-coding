---
name: masterplan-architect
description: Design a structured implementation masterplan for a multi-step feature through interactive Q&A — orient on codebase structure, ask clarifying questions, produce phased plan with tasks, dependencies, and acceptance criteria.
---

# Masterplan Architect

Design structured implementation masterplans through interactive conversation. This skill runs in the main conversation context (not as a spawned agent) because the architect flow is interactive.

## Procedure

### Step 1: Discover Agent Definition

Find the scaffolded masterplan-architect agent in the current project:

```
Glob: .claude/agents/codebase/*-masterplan-architect.md
```

- **Found** → Read the full agent definition file. It contains the project-specific procedure, placeholders already resolved for this project's tech stack, directories, and build commands. Follow its procedure exactly for the remaining steps.
- **Not found** → The project may not be scaffolded yet. Tell the user:
  > "No masterplan-architect agent found. Run `/structured-agentic-coding` to scaffold your project first, or I can design the masterplan using a generic approach."
  >
  > If user wants to proceed without scaffolding, use the fallback procedure below.

### Step 2: Check for Existing Masterplans

Before designing a new plan, check for related work:

```
Glob: docs/masterplans/*.md
Glob: docs/masterplans/executed/*.md
```

If a related masterplan exists, read it to understand what's already been planned or implemented. Note any "out of scope" items that might overlap with the current request.

### Step 3: Follow Agent Definition

Read the discovered agent definition and follow its procedure exactly. The agent definition contains:

1. **Orient** — understand current codebase structure using graph tools or Glob/Grep
2. **Design System Analysis** — if feature has UI, scan existing pages for patterns
3. **Clarify** — ask 5-8 clarifying questions (one per turn, prefer multiple choice)
4. **Design** — produce the masterplan in the required format
5. **Self-Grill** — interrogate your own plan before presenting
6. **Present** — show sections to user for approval
7. **User-Grill** — walk user through decision tree
8. **Write** — save to `docs/masterplans/<feature-name>.md`

Return the masterplan file path as your final output.

## Fallback Procedure (no scaffolded agent)

If no agent definition was found and user wants to proceed:

### Orient
1. `Glob: **/*.md` — find documentation
2. Read ARCHITECTURE.md, GUIDELINES.md if they exist
3. Use Glob/Grep to understand project structure relevant to the feature

### Clarify (5-8 questions, one per turn)
Focus on: scope boundaries, data model, UX expectations, integration points, edge cases.

### Design
Produce a masterplan with this structure:

```markdown
# Masterplan: <Feature Name>

**Goal:** What we're building and why.
**North Star:** Why this matters.

**Scope v1:**
- In scope: ...
- Out of scope: ...

## Architecture
### Flow
### Components
### Key Implementation Details

## Caution Areas

## Implementation Phases

### Phase 1: <name>
#### Tasks
- [ ] **Task 1.1:** <description>
  - Scope: `be`/`fe`/`mixed`
  - Files: <exact paths>
  - Details: |
      WHAT: ...
      HOW: ...
      GUARD: ...
  - Depends on: (none)
  - Bloom: L{1-6}
  - Accept: |
      - [ ] {testable condition}
#### Commit: `feat(<scope>): <message>`

## Key Decisions
## Success Criteria
```

### Present & Approve
Show the plan section by section. Revise based on feedback.

### Write
Save to `docs/masterplans/<feature-name>.md`. Return the path.
