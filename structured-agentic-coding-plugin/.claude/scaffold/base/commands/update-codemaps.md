# Update Codemaps

Scan the repository and update all structural documentation (CODEMAP.md files, ARCHITECTURE.md, GUIDELINES.md) to reflect the current state of the codebase.

## Parse the Request

| User says | Mode |
|-----------|------|
| "update codemaps", "refresh codemaps", "sync codemaps" | incremental |
| "update codemaps --force", "full codemap update", "regenerate codemaps" | full |
| `$ARGUMENTS` contains `--force` or `force` | full |
| (default) | incremental |

## Execution

Discover the codemap-updater agent:

```
Glob: .claude/agents/codebase/*-codemap-updater.md
```

Read the first 3 lines to confirm its role, then spawn it:

```
Agent(
  subagent_type="general-purpose",
  prompt="You are the codemap-updater agent. Read and follow the agent definition at {discovered_agent_path} exactly.

  Mode: {mode}

  Follow the Procedure in the agent definition:
  1. Determine what changed (or scan everything in full mode)
  2. Update affected CODEMAP.md files
  3. Update affected ARCHITECTURE.md and GUIDELINES.md files
  4. Save the update hash
  5. Report what was updated

  Return the summary report as your final output."
)
```

## Response

After the agent completes, relay its summary to the user. If the agent reports "up to date", say so and stop.
