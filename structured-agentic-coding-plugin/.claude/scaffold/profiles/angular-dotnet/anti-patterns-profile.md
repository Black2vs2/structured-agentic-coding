# Anti-Patterns — Angular + .NET Fullstack

Cross-layer failure modes specific to the Angular + .NET fullstack combination. Appended to anti-patterns after the angular-fe and dotnet-be profile anti-patterns.

## OpenAPI Contract

- NEVER edit generated TypeScript client files under `__FE_DIR__/libs/core/api/src/lib/generated/` — fix the backend API contract and run `/openapi-sync` instead
- Do NOT work around a contract mismatch with `as any` / `as unknown as` casts — update the backend DTO, regenerate, and let the types flow
- When changing a DTO shape, run `/openapi-sync` in the same commit — shipping a backend change without regenerating the client breaks the frontend silently

## Fullstack Lifecycle

- When the backend must be running for OpenAPI regen or E2E tests, ALWAYS poll `/health` — never `sleep N`
- ALWAYS stop the backend process after sync/test operations — never leave orphan `dotnet` processes
- ALWAYS build the backend before starting it — never start from stale compilation
