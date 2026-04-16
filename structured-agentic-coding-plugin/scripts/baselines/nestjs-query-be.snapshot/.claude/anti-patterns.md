# Anti-Patterns

Known failure modes from past executions. Read by:
- **Architect** — for task design (avoid repeating mistakes)
- **Executor** — for prompt injection (warn dev agents)
- **Reviewer** — for regression detection

---

## General — Task Discipline

- Don't modify files outside task's `Files:` list — STOP and report if other files need changes
- Don't add features beyond task description — scope creep causes regressions
- Always run build verification after changes
- Stop and report if task seems wrong or conflicts with existing code
- Don't skip running tests
- Read existing file patterns before creating new files — follow them exactly

### Surrendering too quickly
**Pattern:** Agent marks a task as blocked or escalates after one failed attempt.
**Rule:** Before marking anything as blocked, try at least 2 different approaches. For code issues, try a different implementation path. For test failures, try adjusting the approach. Only then escalate with: what was tried, why it failed, suggested alternatives.
**Why:** Most tasks have multiple valid solutions. The first approach failing doesn't mean the task is impossible.

### Critical thinking deficit
**Pattern:** Agent blindly follows instructions without questioning assumptions or proposing alternatives.
**Rule:** Verify assumptions before implementing. If you see a better approach than what's prescribed, propose it (but don't implement without approval). Report problems early — don't wait until the end of a phase to mention a fundamental issue you noticed at the start. Balance critical thinking with execution speed — don't over-analyze to the point of paralysis.

### Skipping tests silently
**Pattern:** Agent reports "tests pass" but actually skipped failing or difficult tests.
**Rule:** SKIP = FAIL. Any test report with skipped tests is treated as a failure. Tests must either run and pass, or explicitly fail with a reason. Never skip a test to make a green report.

## Frontend — Patterns

- Read the closest existing page/component and follow its structure exactly
- No new architectural patterns (base classes, store features, layout systems) without explicit masterplan approval
- Don't modify generated/auto-generated files — fix the source instead

## Backend — Patterns

- All business logic through the designated handler/service pattern — not in controllers
- Don't bypass audit or validation interceptors with raw SQL or direct DB access
- Don't return full DTOs from create operations — return identifiers only

## Process Management

- Always use health check polling when starting services (never `sleep N`)
- Always stop backend services when done (even on failure)
- Always build before starting services

### RACE-001: Concurrent file writes
**Pattern:** Two parallel agents write to the same file simultaneously, causing merge conflicts or data loss.
**Rule:** No two agents dispatched in the same batch may have overlapping files in their `Files:` lists. The executor's dependency analysis already checks this — if overlap exists, tasks must run sequentially, never in parallel. If dispatching parallel worktree agents, verify file disjointness before dispatch.
**Why:** Git merge conflicts from concurrent edits waste more time than sequential execution would have.

# Anti-Patterns — NestJS + nestjs-query + Firebase + Bun

Known failure modes specific to this stack. Check each before committing backend code.

---

## `synchronize: true` on TypeORM DataSource

**Trigger:** `new DataSource({ ..., synchronize: true })` or `TypeOrmModule.forRoot({ synchronize: true })` anywhere in config.

**Why it's wrong:** Auto-syncing the schema from entities circumvents migrations, silently destroys data in production, and creates drift between environments. TypeORM's sync is not safe for any shared or production-like DB.

**Fix:** Always `synchronize: false`. Apply schema changes through migrations (`bun run migration:generate <Name>` + `bun run migration:run`). Use the DBML file (`database/database-simplified.dbml`) as the source of truth for schema design reviews.

**Related rules:** BE-TYPEORM-001

---

## Manual `@UseGuards(...)` on a GraphQL resolver

**Trigger:** `@UseGuards(UserAuthGuard)` (or any project guard) on a `@Resolver` class or `@Query`/`@Mutation` method.

**Why it's wrong:** The auth chain (`UserAuthGuard` → `RolesGuard` → `PartnerAssignedGuard`) is registered as `APP_GUARD` in `AppModule` and applies globally. Redeclaring it locally either duplicates work or — worse — masks intent if someone later tries to scope the global chain.

**Fix:** Remove the local `@UseGuards`. Use `@RequiredRoles(...)` and `@PartnerNotRequired()` decorators to tune the global chain's behavior per-endpoint.

**Related rules:** BE-AUTH-001, BE-AUTH-003

---

## Hand-editing `src/schema.gql`

**Trigger:** Any git diff touching `src/schema.gql` (or configured equivalent) that did not come from a resolver change + dev server restart.

**Why it's wrong:** The schema file is emitted by `@nestjs/graphql` from the code-first resolver definitions. Manual edits desync the file from the code and are overwritten on the next server boot.

**Fix:** Change the resolver / DTO / type, then restart `bun run start:dev` to regenerate. If the regeneration doesn't match expectations, the resolver is wrong — not the schema.

**Related rules:** BE-QUERY-002

---

## Explicit Id assignment on entities

**Trigger:** `new Entity({ id: 'some-uuid', ... })` or `entity.id = uuid()` before `save()`.

**Why it's wrong:** Entities use TypeORM's auto-generated UUID primary keys (`@PrimaryGeneratedColumn('uuid')`). Explicit assignment bypasses the DB's generation strategy and introduces a class of bugs where pre-commit mutations look like upserts.

**Fix:** Drop the manual id. Let TypeORM handle it. If you need to know the id after save, read it from the returned entity.

**Related rules:** BE-TYPEORM-004

---

## BullMQ / `@nestjs/bull` without justification

**Trigger:** `@nestjs/bull` or `@nestjs/bullmq` in `package.json`; `BullModule` or `BullMqModule` imports.

**Why it's wrong:** Project convention is pg-boss (Postgres-backed queue — no extra Redis dependency). Adopting BullMQ on top adds infra surface (Redis) and two queue systems to reason about.

**Fix:** If the use case truly needs BullMQ (distributed fanout, advanced retry DAGs), add an ADR explaining why pg-boss is insufficient. Otherwise, use `QueueService` (the pg-boss wrapper).

**Related rules:** BE-QUEUE-002

---

## Bypassing Firebase token verification

**Trigger:** Reading `context.req.headers.authorization` directly in a resolver/service; `context.req.user` set outside `UserAuthGuard`; custom JWT decode.

**Why it's wrong:** `UserAuthGuard` verifies the Firebase ID token via the Admin SDK and attaches a validated user object. Bypassing it trusts an unverified header, which is a trivial auth-bypass vulnerability.

**Fix:** Use `@LoggedUser()` to read the user. Do not reach into `req.headers` yourself.

**Related rules:** BE-AUTH-002, BE-SEC-001

---

## npm/yarn/pnpm commands instead of bun

**Trigger:** `npm install`, `yarn`, `pnpm install` in docs, scripts, or CI; `package-lock.json`/`yarn.lock`/`pnpm-lock.yaml` committed.

**Why it's wrong:** The project runtime and lockfile is bun. Mixing package managers produces divergent lockfiles, different install behaviors, and breaks the assumption that `bun.lock` is the ground truth.

**Fix:** Use `bun install` / `bun run <script>`. Remove any alternate lockfile. In CI, always install via bun.

**Related rules:** BE-CI-001

---

## `ValidationPipe` disabled or narrowed globally

**Trigger:** `app.useGlobalPipes(new ValidationPipe({ whitelist: false, ... }))` or no global `ValidationPipe` at all in `main.ts`.

**Why it's wrong:** `ValidationPipe` with `{ transform: true, whitelist: true }` enforces `class-validator` + `class-transformer` rules AND strips unknown input fields. Narrowing it opens the API to field-injection and skips FK existence validators.

**Fix:** Keep the global `ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: false })` in `main.ts`. Tune per-endpoint validation via DTOs, not by relaxing the pipe.

**Related rules:** BE-VAL-001

---

## Direct SQL write via `query()` / raw statements

**Trigger:** `dataSource.query('INSERT ...')`, `repo.query('UPDATE ...')`, or `@Query()` raw SQL in service methods for mutations.

**Why it's wrong:** Bypasses TypeORM's tracking, any audit interceptors, and the entity lifecycle hooks. Soft-delete triggers (the `isActive` boolean pattern) will not fire. Type safety is lost.

**Fix:** Use repository methods (`save`, `update`, `softDelete`, `remove`). If a bulk operation is genuinely needed, wrap it in an explicit transaction and document the choice with a comment.

**Related rules:** BE-TYPEORM-006

---

## Tests diverging from real migrations

**Trigger:** Unit tests that mock `Repository<Entity>` with fields that do not exist on the actual entity; e2e tests against an in-memory DB with a schema drifted from the production migrations.

**Why it's wrong:** Tests pass while production fails. Mocks become the spec instead of reflecting the code.

**Fix:** When mocking repositories via `getRepositoryToken`, type the mock against the real entity. Run e2e tests against a Postgres instance (managed or local `__DB_START__`) with all migrations applied (`bun run migration:run` in the test setup hook). Flag any mock that diverges from the entity.

**Related rules:** BE-TEST-002, BE-TYPEORM-003

---

## Changing an entity without a matching migration

**Trigger:** A diff modifies a file under `src/**/entity/*.ts` (touching `@Column`, `@Entity`, `@ManyToOne`, `@OneToMany`, `@Index`, `@PrimaryGeneratedColumn`, or column options: type, nullable, default, length, precision) but adds no new file under `database/migrations/`.

**Why it's wrong:** The entity is the code-side of the schema; the migration is the DB-side. A change to only one side produces drift: code expects columns/types the DB doesn't have, or the DB has columns the entity ignores. Fresh-DB deploys break; existing DBs silently desync.

**Fix:** After editing any entity, run `bun run migration:generate <Name> <DescriptiveName>`. Commit the generated migration in the same PR. Never rely on `synchronize: true` (see separate anti-pattern).

**Related rules:** BE-TYPEORM-007

---

## Missing explicit GraphQL scalar type on numeric `@FilterableField()`

**Trigger:** `@FilterableField(() => Number)` on a DTO field representing a decimal (e.g., `value`, `weightKg`, `customPrice`) without specifying `Float` from `@nestjs/graphql`, or an integer field without specifying `Int`.

**Why it's wrong:** `@FilterableField(() => Number)` resolves to the GraphQL `Float` scalar in most cases but is ambiguous. When nestjs-query generates the schema, `Number` sometimes causes the NestJS/Apollo bootstrap to throw because it cannot determine the correct GraphQL scalar (Float vs Int). This was hit during past implementations where multiple DTOs initially used `@FilterableField(() => Number)` which broke the e2e test bootstrap and required a fixer pass to add explicit `Float` / `Int` annotations.

**Fix:** Always use the explicit GraphQL scalar:
- Decimals: `@FilterableField(() => Float)` (import `Float` from `@nestjs/graphql`)
- Integers: `@FilterableField(() => Int)` (import `Int` from `@nestjs/graphql`)
- Never use `@FilterableField(() => Number)` — it is ambiguous.

**Related rules:** BE-QUERY-001

---

## Missing `CreateDTOClass` / `UpdateDTOClass` on CRUDResolver

**Trigger:** A mutations resolver extends `CRUDResolver(DTO, { ... })` with create/update enabled but does NOT pass `CreateDTOClass` or `UpdateDTOClass` in the options.

**Why it's wrong:** The module-level `dtos[].CreateDTOClass` in `NestjsQueryGraphQLModule.forFeature()` only registers hook and authorizer providers — it does NOT flow into CRUDResolver. Without explicit `CreateDTOClass`, nestjs-query falls back to `OmitType(DTOClass, [], InputType)`, exposing server-managed fields (`id`, `createdAt`, `updatedAt`, `status`) in create/update mutations.

**Fix:** Pass `CreateDTOClass: XxxCreateInputDTO` and `UpdateDTOClass: XxxUpdateInputDTO` in the CRUDResolver options on every mutations resolver that uses auto-generated CRUD.

**Related rules:** BE-QUERY-014
