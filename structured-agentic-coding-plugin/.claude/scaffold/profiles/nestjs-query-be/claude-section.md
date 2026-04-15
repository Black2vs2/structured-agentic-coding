<!--
Profile CLAUDE.md overlay for nestjs-query-be.

In Phase 6 the skill appends this file's visible content after the base
`_be-section.md` during BE-scope or fullstack scaffolding. Everything
between the HTML comments is commentary and will be stripped; the
visible markdown below ships in the user's CLAUDE.md.
-->

### NestJS-query specifics

- `__GRAPHQL_SCHEMA_OUT__` is auto-generated from resolvers via `@nestjs/graphql` code-first. **Never hand-edit** — restart the dev server (`__BE_RUN__`) to regenerate.
- Feature module anatomy: `src/<feature>/{dto/, entity/, service/, resolver/, assembler/, validators/, <feature>.module.ts}`. All modules export their service and `TypeOrmModule` for cross-module reuse.
- All DTO fields use `@FilterableField`; services extend `TypeOrmQueryService`; resolvers extend `CRUDResolver`; paging strategy is OFFSET only (not CURSOR).

### Auth chain

Global guards (registered as `APP_GUARD`): `UserAuthGuard` → `RolesGuard` → `PartnerAssignedGuard`. Do NOT add `@UseGuards(...)` on GraphQL resolvers — the global chain already covers them. Use `@PartnerNotRequired()` only with a justification comment. `@AdminOnlyField()` fields are filtered for non-admins by `AdminFieldFilterInterceptor`.

### Migrations (TypeORM)

- Run pending: `__MIGRATION_RUN__`
- Generate new: `__MIGRATION_GENERATE__`
- Revert last: `__MIGRATION_REVERT__`
- Never hand-edit migrations already committed under `database/migrations/`. Fix-forward by creating a new migration.

### Queue & Firebase

- Job queue: pg-boss (not BullMQ). Handlers must be idempotent.
- Firebase emulator (local auth testing): `__FIREBASE_EMULATOR__`
