# SPS Scaffold Dry-Run Report

**Date:** 2026-04-15
**Plugin version:** 4.3.0
**Target repos:**
- `/Users/andreagallo/projects/sps/sps-app-backend` — profile `nestjs-query-be`, SCOPE `be`
- `/Users/andreagallo/projects/sps/sps-app-frontend` — profile `refine-nestjs-query-fe`, SCOPE `fe`

This report documents what would happen if `/structured-agentic-coding` were invoked in each SPS repo. No files were written to the target repos — this is a projection based on the profile manifests and a prior deep scan of both stacks.

---

## sps-app-backend — profile `nestjs-query-be`

### Context-pass findings (Phase 0 of skill)

From `CLAUDE.md` and `README.md`:
- "Bun runtime" → sets `FE_RUNTIME`/`BE_RUNTIME = bun`
- Firebase Admin SDK usage → `FIREBASE_SCOPE = admin-sdk`
- nestjs-query GraphQL patterns explicitly documented → `CRUD_LIB = nestjs-query`
- pg-boss queue used (not BullMQ) → `QUEUE_LIB = pg-boss`
- No `docker-compose.yml` at the root → DB is managed (Cloud SQL)

### Profile recommendation

**Silent scan:**
- `@nestjs/core` in `package.json` dependencies ✓
- `@ptc-org/nestjs-query-graphql` in dependencies ✓
- `bun.lock` present ✓
- `firebase.json` at root ✓

**Recommendation: `nestjs-query-be`** — strong match.

### User inputs

| Variable | Value | Source |
|---|---|---|
| `PREFIX` | `sps-backend` | user choice |
| `PROJECT_NAME` | `SPS Backend` | user choice |
| `PROJECT_DESC` | "Warehouse management platform API — orders, inventory, shipments" (example) | user input |
| `SCOPE` | `be` | default for profile |

### Detected variables

| Variable | Value | Source |
|---|---|---|
| `BE_RUNTIME` | `bun` | context-inferred (CLAUDE.md) |
| `BE_BUILD` | `bun run build` | package-json-script |
| `BE_RUN` | `bun run start:dev` | package-json-script |
| `BE_TEST` | `bun run test` | package-json-script |
| `BE_TEST_E2E` | `bun run test:e2e` | package-json-script |
| `BE_FORMAT` | `bun run format` | package-json-script |
| `BE_LINT` | `bun run lint:fix` | package-json-script |
| `MIGRATION_RUN` | `bun run migration:run` | package-json-script |
| `MIGRATION_GENERATE` | `bun run migration:generate <Name>` | package-json-script |
| `MIGRATION_REVERT` | `bun run migration:revert` | package-json-script |
| `DB_MANAGED` | `true` | glob-absent (no docker-compose*.yml) |
| `DB_START` | skipped | `required_if { DB_MANAGED: false }` evaluates false |
| `FIREBASE_EMULATOR` | `bun run firebase:emulator:start` | package-json-script |
| `GRAPHQL_SCHEMA_OUT` | `src/schema.gql` | regex-capture-from-files (autoSchemaFile in src/main.ts or static default) |

**TODO placeholders:** none expected.

### Files scaffolded

Counts from fixture baseline:

- `.claude/agents/codebase/sps-backend-{masterplan-architect,masterplan-executor,masterplan-reviewer,doc-enforcer}.md` — 4 core
- `.claude/agents/domain/sps-backend-{research,impact-analyst,test-writer,migration-reviewer}.md` — 4 domain
- `.claude/agents/sps-backend-{feature-developer,code-reviewer,fixer}.md` — 3 backend (SCOPE=be + BE_DIR=.)
- `.claude/agents/be-scans/{architecture,typeorm,nestjs-query,auth,validation,queue,api,security,ci-secrets,testing}.md` — 10 scan playbooks
- `.claude/rules/be-rules.json` — 42 rules
- `.claude/commands/{masterplan,masterplan-review,rebuild-graph,kill}.md` — 4 commands
- `.claude/templates/{ARCHITECTURE,GUIDELINES}.template.md` — 2 templates
- `.claude/AGENTS.md`, `.claude/anti-patterns.md`, `.claude/settings.json`
- `CLAUDE.md` (fragments + profile overlay with Firebase emulator, TypeORM migrations, pg-boss notes)
- `.claude/scaffold-manifest.json`

Approx 34 files.

### Applicable rules

All 42 `BE-*` rules apply. Highest-value enforcement for SPS:
- **BE-QUERY-001**: `@FilterableField` on every DTO field (matches the project's code-first pattern)
- **BE-AUTH-001**: no manual `@UseGuards()` — global chain covers (matches `UserAuthGuard → RolesGuard → PartnerAssignedGuard` setup)
- **BE-TYPEORM-001**: no `synchronize: true` (project already enforces this)
- **BE-VAL-001**: `@Trim()` on string inputs (already in project convention)
- **BE-CI-002**: secrets parity between `cloudbuild.yaml` and `deploy-*.yml` (catches a real deploy-time footgun)
- **BE-QUEUE-002**: no BullMQ (reinforces the pg-boss choice)

### Scans that will run on first `/masterplan-review`

All 10 playbooks. Critical ones to focus on first:
1. `security.md` — Helmet, Throttler, Turnstile, CSP, no hardcoded secrets
2. `auth.md` — guard chain not bypassed, Firebase token verify
3. `ci-secrets.md` — cloudbuild.yaml ↔ deploy-*.yml parity
4. `typeorm.md` — no `synchronize: true`, down() completeness, FK onDelete

---

## sps-app-frontend — profile `refine-nestjs-query-fe`

### Context-pass findings (Phase 0)

From `CLAUDE.md`:
- "Refine.dev 5.x is the central framework" → `FRAMEWORK_STACK = refine`
- "Bun is required — never use npm/yarn/pnpm" → `FE_RUNTIME = bun`
- "Zod imports must use `zod/v4`" → `ZOD_VERSION = v4` (signal for FE-FORM-001 rule)
- "`useTranslation` from `@refinedev/core` only" → documented for FE-I18N-001
- Protected paths listed: `src/graphql/*.ts`, `patches/`

From `components.json`: shadcn/ui style "new-york" → `UI_LIB = shadcn`

From `package.json`: `@tailwindcss/vite` → `TAILWIND_VERSION = v4`

### Profile recommendation

**Silent scan:**
- `react@^19` + `vite@^7` ✓
- `@refinedev/core@^5` ✓
- `@refinedev/nestjs-query` ✓
- `bun.lock` present ✓
- `graphql.config.ts` present ✓

**Recommendation: `refine-nestjs-query-fe`** — strong match.

### User inputs

| Variable | Value | Source |
|---|---|---|
| `PREFIX` | `sps-frontend` | user choice |
| `PROJECT_NAME` | `SPS Frontend` | user choice |
| `PROJECT_DESC` | "Warehouse management admin UI — Refine.dev + GraphQL" (example) | user input |
| `SCOPE` | `fe` | default for profile |

### Detected variables

| Variable | Value | Source |
|---|---|---|
| `FE_RUNTIME` | `bun` | context-inferred (CLAUDE.md + bun.lock) |
| `FE_SERVE` | `bun run dev` | package-json-script |
| `FE_BUILD` | `bun run build` | package-json-script |
| `FE_BUILD_STAGE` | `bun run build:stage` | package-json-script |
| `FE_FORMAT` | `bun run format` | package-json-script |
| `FE_LINT` | `bun run lint` | package-json-script |
| `FE_LINT_FIX` | `bun run lint:fix` | package-json-script |
| `FE_TYPECHECK` | `bun run tsc` | package-json-script |
| `FE_TEST` | **TODO** | no `test` script in package.json yet (Vitest harness to be installed) |
| `E2E_CMD` | **TODO** | no playwright.config.* / cypress.config.* yet |
| `GRAPHQL_CODEGEN` | `bun run codegen` | package-json-script |
| `GRAPHQL_SCHEMA_SRC` | **user input required** | `graphql.config.ts` references the backend introspection URL — user confirms (e.g., `http://localhost:3000/graphql` for dev, `../sps-app-backend/src/schema.gql` for monorepo-symlinked) |

**TODO placeholders:** `FE_TEST`, `E2E_CMD` — expected, the test harness is not installed yet. When Vitest arrives, re-run `/upgrade-agentic-coding` and update these.

**User input required:** `GRAPHQL_SCHEMA_SRC` — the skill will read `graphql.config.ts` and show the detected value for confirmation.

### Files scaffolded

- `.claude/agents/codebase/sps-frontend-{masterplan-architect,executor,reviewer,doc-enforcer}.md` — 4 core
- `.claude/agents/domain/sps-frontend-{research,impact-analyst,test-writer,resource-generator,graphql-codegen-sync}.md` — 5 domain
- `.claude/agents/sps-frontend-{feature-developer,code-reviewer,fixer}.md` — 3 frontend
- `.claude/agents/fe-scans/{refine-providers,graphql-operations,forms-zod,ui-theming,auth-firebase,i18n,env-vars,protected-paths,package-manager,testing}.md` — 10 scan playbooks
- `.claude/rules/fe-rules.json` — 44 rules
- `.claude/commands/{masterplan,masterplan-review,rebuild-graph,kill,graphql-codegen-sync}.md` — 5 commands (includes profile-specific `/graphql-codegen-sync`)
- Standard templates, AGENTS.md, anti-patterns.md, settings.json, CLAUDE.md, scaffold-manifest.json

Approx 36 files.

### Applicable rules

All 44 `FE-*` rules apply. Highest-value for SPS:
- **FE-FORM-001**: Zod from `zod/v4` (catches the most common regression)
- **FE-I18N-001**: `useTranslation` from `@refinedev/core` (project-specific convention)
- **FE-PROT-001 / FE-PROT-002**: `src/graphql/types.ts` and `schema.types.ts` never hand-edited
- **FE-ENV-001**: no `process.env.*`, only `import.meta.env.VITE_*`
- **FE-BUN-001**: no competing lockfiles
- **FE-UI-003**: no hardcoded hex colors in components
- **FE-REFINE-002**: no direct `fetch()` bypassing the dataProvider

### Scans priorities

1. `protected-paths.md` — generated GraphQL files integrity
2. `refine-providers.md` — resource registration, dataProvider/authProvider wiring
3. `graphql-operations.md` — inline gql conventions, codegen freshness
4. `forms-zod.md` — Zod v4 import + error map
5. `ui-theming.md` — shadcn + Tailwind + CSS variables

---

## Cross-repo notes

- **Shared placeholders**: `PREFIX` differs intentionally (`sps-backend` vs `sps-frontend`) so agent filenames don't collide if both sets of agents are ever co-located in tooling
- **GraphQL coordination**: FE's `GRAPHQL_SCHEMA_SRC` points at BE's runtime endpoint (introspection) or a local path. When BE schema changes, FE runs `/graphql-codegen-sync` to regenerate typed operations
- **Deploy coordination**: BE deploy produces a new Cloud Run revision; FE's next `FE_BUILD` against the updated schema catches breaking changes at typecheck time (FE-GQL-004 rule enforces codegen freshness)

## Verification checklist

Once scaffolded, to verify the setup is correct:

- [ ] `CLAUDE.md` in each repo renders without unresolved `__KEY__` tokens
- [ ] `.claude/scaffold-manifest.json` records the correct profile and scope
- [ ] `/masterplan-review` completes a full scan without false positives (tune rules if needed)
- [ ] A trial `/graphql-codegen-sync` regenerates types successfully (FE only)
- [ ] Firebase emulator command succeeds locally (BE only)
- [ ] Test-presence rules report as severity `info` (expected until test harnesses are installed)

## Known gaps (will close as SPS evolves)

- No Vitest or Jest harness installed yet — `FE_TEST`, `BE_TEST` rules ship at `info` severity. Raise to `warning` after harnesses land.
- FE has no E2E config yet — `E2E_CMD` starts as TODO. Install Playwright + re-run upgrade to update.
- `src/graphql/types.ts` file-naming assumption: some projects emit to `src/graphql/index.ts` instead. If that's the case for SPS-FE, update the FE-PROT rules manually.
