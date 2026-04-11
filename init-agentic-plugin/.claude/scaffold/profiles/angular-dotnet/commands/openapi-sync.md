# OpenAPI Sync

Regenerate the frontend TypeScript API client from the backend's live OpenAPI specification. Handles the full lifecycle: database, backend start, client generation, cleanup, and frontend build verification.

## Execution

Spawn the openapi-sync agent:

```
Agent(
  subagent_type="general-purpose",
  prompt="You are the openapi-sync agent. Read and follow the agent definition at .claude/agents/domain/__PREFIX__-openapi-sync.md exactly.

  Follow the Procedure in the agent definition:
  1. Ensure database is running (Docker)
  2. Build and start the backend in background
  3. Wait for readiness, verify OpenAPI spec is accessible
  4. Run npm run openapi-gen in frontend
  5. Stop the backend
  6. Fix any type mismatches (remove stale casts, update stores)
  7. Format and build frontend
  8. Report results

  Return the summary report as your final output."
)
```

## Response

After the agent completes, relay its summary to the user. If there were frontend build failures the agent couldn't resolve, highlight them for manual attention.
