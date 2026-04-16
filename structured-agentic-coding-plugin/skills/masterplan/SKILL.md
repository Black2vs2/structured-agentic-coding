---
name: masterplan
description: Orchestrate the masterplan lifecycle — design implementation plans with the architect, execute them with dev agents, review completed work, or resume interrupted plans. Routes subcommands automatically. Use when the user says plan, masterplan, add/build/implement feature, design and build, roadmap a feature.
---

# Masterplan Orchestrator

Routes masterplan subcommands to the appropriate skill. Handles the full lifecycle when no subcommand is given.

## Routing

Parse the first word of the user's input after the skill name to determine the subcommand:

| First word | Action |
|---|---|
| `architect`, `design`, `plan`, `create` | Invoke the **`structured-agentic-coding:masterplan-architect`** skill via the Skill tool |
| `executor`, `execute`, `run`, `implement` | Invoke the **`structured-agentic-coding:masterplan-executor`** skill via the Skill tool |
| `review`, `audit`, `check`, `verify` | Invoke the **`structured-agentic-coding:masterplan-review`** skill via the Skill tool |
| `resume` | Find most recent incomplete masterplan, then invoke **`structured-agentic-coding:masterplan-executor`** |
| _(no subcommand or feature description)_ | Full lifecycle: architect → confirm → executor |

Pass the remaining text as args to the invoked skill.

## Full Lifecycle (no subcommand)

When the user provides a feature description without a subcommand (e.g., `/masterplan add profile pictures`):

### Step 1: Check for Existing Masterplan

```
Glob: docs/masterplans/*.md
```

If a matching masterplan exists with unchecked `- [ ]` tasks, ask:
> "Found existing masterplan at `{path}` with {N} tasks remaining. Resume execution?"
> - **Yes** → invoke **`structured-agentic-coding:masterplan-executor`** skill with the path
> - **No** → proceed to Step 2

If all tasks are checked, inform user and ask if they want a new one.

### Step 2: Invoke Architect

Invoke the **`structured-agentic-coding:masterplan-architect`** skill via the Skill tool, passing the user's feature description as args.

Wait for the architect to complete. It returns the masterplan file path.

### Step 3: Confirm Execution

Ask the user:
> "Masterplan written to `{path}`. Execute now?"
> - **Yes** → invoke **`structured-agentic-coding:masterplan-executor`** skill with the path
> - **No** → done. Tell user: "Execute later with `/masterplan execute {path}`"

## Resume Flow

When subcommand is `resume`:

1. `Glob: docs/masterplans/*.md` — find all masterplans
2. Read each, find the most recent one with unchecked `- [ ]` tasks
3. Confirm with user: "Resume masterplan at `{path}`?"
4. Invoke **`structured-agentic-coding:masterplan-executor`** skill with the path
