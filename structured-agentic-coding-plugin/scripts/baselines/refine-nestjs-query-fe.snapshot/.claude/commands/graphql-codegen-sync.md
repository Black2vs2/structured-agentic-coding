---
description: Run GraphQL codegen, optionally refreshing the schema source first.
---

# /graphql-codegen-sync

Regenerate `src/graphql/*.ts` from the current GraphQL schema. Optionally update the schema source (URL or local path) before running codegen.

## Usage

```
/graphql-codegen-sync
/graphql-codegen-sync --schema-src http://localhost:3000/graphql
/graphql-codegen-sync --schema-src ../sps-app-backend/src/schema.gql
```

## Procedure

1. If `--schema-src <value>` is provided, update `graphql.config.ts`'s `schema:` field to match.
   - Remote URL: use when the backend exposes GraphQL introspection (typically dev or staging environments).
   - Local path: use when the backend repo is available on disk (monorepo or a symlinked sibling).
   - Omit `--schema-src` to leave the existing schema source untouched.

2. Dispatch the `testrnq-graphql-codegen-sync` domain agent.

3. The agent:
   - Edits `graphql.config.ts` if a new schema source was passed
   - Runs `bun run codegen` to regenerate `src/graphql/schema.types.ts` and `src/graphql/types.ts`
   - Runs `bun run tsc` to confirm the rest of the codebase still compiles against the new types
   - Runs `bun run format` to normalize the output

4. The agent reports:
   - Schema source used
   - Whether the config was modified
   - Codegen status
   - Typecheck status + any type drift
   - Breaking changes detected (removed types, renamed fields) — these require user confirmation before commit

## Guardrails

- The generated files under `src/graphql/` are NEVER hand-edited. Any diff to those files must come from this command.
- If the schema source is unreachable (network error, introspection disabled, missing file), the agent stops and reports — no partial regeneration.
- If the regenerated schema introduces breaking changes, the agent surfaces them explicitly before the user commits.

## Related

- The profile's `feature-developer` agent runs this command automatically after adding or changing inline `gql` operations.
- `/masterplan` workflows that include frontend changes invoke this command after backend schema migrations land.
