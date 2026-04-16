# Anti-Patterns — .NET Profile

Tech-stack-specific failure modes for .NET / C# backends. These are merged with the base anti-patterns during scaffolding.

## CQRS & Handler Patterns

- All business logic goes through MediatR handlers — controllers only call `mediator.Send()` and return the result
- Do NOT bypass the audit interceptor with raw SQL INSERT/UPDATE statements
- Do NOT assign `Id = Guid.NewGuid()` or `Id = Guid.CreateVersion7()` on entities inheriting BaseEntity — EF Core handles it
- Do NOT use `throw new Exception(...)` or `throw new InvalidOperationException(...)` — use the ApiException hierarchy
- Do NOT return full DTOs from create commands — return `Guid` only (the created entity's Id)
- Use primary constructors for handlers (BE-CQRS-001)

## EF Core & Data Patterns

- Do NOT use `.ToList()` / `.ToArray()` — use collection expressions `[.. source]`
- Always use `.AsNoTracking()` in query handlers
- Use `HasConversion<string>()` for all enum properties in EF configurations
- Use `DeleteBehavior.Restrict` by default — `Cascade` requires justification comment
- Do NOT manually edit migration code files (`Migrations/2*.cs`, `AppDbContextModelSnapshot.cs`)

## State Machine Enforcement

- Status changes must go through entity domain methods — never direct assignment in handlers
- Terminal states (Completed, Expired, Revoked) must be immutable — no further transitions allowed
- Always capture old state before transitions for audit logging

## Process Management

- When the backend needs to be running (for OpenAPI regen, E2E tests), ALWAYS use health check polling — never `sleep N`
- ALWAYS stop the backend process after operations complete — never leave orphan processes
- ALWAYS build backend before starting it — never start from stale compilation
