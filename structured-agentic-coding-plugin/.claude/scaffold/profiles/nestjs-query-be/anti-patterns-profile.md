# Anti-Patterns — NestJS + nestjs-query + Firebase + Bun

Known failure modes specific to this stack. Check each before committing backend code.

---

## `synchronize: true` on TypeORM DataSource

**Trigger:** `new DataSource({ ..., synchronize: true })` or `TypeOrmModule.forRoot({ synchronize: true })` anywhere in config.

**Why it's wrong:** Auto-syncing the schema from entities circumvents migrations, silently destroys data in production, and creates drift between environments. TypeORM's sync is not safe for any shared or production-like DB.

**Fix:** Always `synchronize: false`. Apply schema changes through migrations (`__MIGRATION_GENERATE__` + `__MIGRATION_RUN__`). Use the DBML file (`database/database-simplified.dbml`) as the source of truth for schema design reviews.

**Related rules:** BE-TYPEORM-001

---

## Manual `@UseGuards(...)` on a GraphQL resolver

**Trigger:** `@UseGuards(UserAuthGuard)` (or any project guard) on a `@Resolver` class or `@Query`/`@Mutation` method.

**Why it's wrong:** The auth chain (`UserAuthGuard` → `RolesGuard` → `PartnerAssignedGuard`) is registered as `APP_GUARD` in `AppModule` and applies globally. Redeclaring it locally either duplicates work or — worse — masks intent if someone later tries to scope the global chain.

**Fix:** Remove the local `@UseGuards`. Use `@RequiredRoles(...)` and `@PartnerNotRequired()` decorators to tune the global chain's behavior per-endpoint.

**Related rules:** BE-AUTH-001, BE-AUTH-003

---

## Hand-editing `__GRAPHQL_SCHEMA_OUT__`

**Trigger:** Any git diff touching `src/schema.gql` (or configured equivalent) that did not come from a resolver change + dev server restart.

**Why it's wrong:** The schema file is emitted by `@nestjs/graphql` from the code-first resolver definitions. Manual edits desync the file from the code and are overwritten on the next server boot.

**Fix:** Change the resolver / DTO / type, then restart `__BE_RUN__` to regenerate. If the regeneration doesn't match expectations, the resolver is wrong — not the schema.

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

**Fix:** When mocking repositories via `getRepositoryToken`, type the mock against the real entity. Run e2e tests against a Postgres instance (managed or local `__DB_START__`) with all migrations applied (`__MIGRATION_RUN__` in the test setup hook). Flag any mock that diverges from the entity.

**Related rules:** BE-TEST-002, BE-TYPEORM-003
