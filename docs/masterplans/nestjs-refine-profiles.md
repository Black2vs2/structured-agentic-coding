# Masterplan: nestjs-refine-profiles

**Goal:** Add two stack-specific profiles (`nestjs-query-be`, `refine-nestjs-query-fe`) to the plugin, refactor the scaffolding system to support single-stack scope for split-repo setups, and migrate `angular-dotnet` to the same manifest-driven architecture.

**North Star:** Make `structured-agentic-coding` usable on `sps-app-backend` and `sps-app-frontend` with profiles that enforce the real conventions of those stacks (Refine.dev, nestjs-query, Firebase Auth, Bun, TypeORM, pg-boss) — without breaking the existing `angular-dotnet` profile.

---

## Scope v1

### In scope
- `scaffold.sh` refactor: `SCOPE=fe|be|fullstack` flag, per-profile `variables.json` manifest, concatenation of fragmented templates.
- Fragment `base/CLAUDE.md`, `base/AGENTS.md`, `base/settings.json` into `_core + _fe-section + _be-section` with **byte-identical output** in fullstack mode.
- Migrate `angular-dotnet` to the new manifest-driven system (byte-identity verified via smoke test).
- Profile `nestjs-query-be`: agents, rules (~45), scan playbooks (~10), anti-patterns, claude-section, variables.json.
- Profile `refine-nestjs-query-fe`: agents, rules (~45), scan playbooks (~12), anti-patterns, claude-section, variables.json, `/graphql-codegen-sync` command.
- `structured-agentic-coding` skill: context-first detection (read README/CLAUDE.md/docs before systematic glob), dynamic manifest loading, SCOPE question, profile recommendation updated for the new profiles.
- `upgrade-agentic-coding` skill: **always-active** profile-migration detection that proposes switching to a better-matching profile when the repo has diverged.
- Plugin version bump 4.2.0 → 4.3.0 + CHANGELOG + README.

### Out of scope
- Generic profiles `react-vite-fe` / `nestjs-be` (this iteration is specific to Refine + nestjs-query).
- Installing test harnesses on SPS repos (separate work; rules enforce conventions when tests arrive).
- Fully composable profiles (roadmap — Option C of the design discussion).
- Auto-detection sophistication beyond what's specified (current Glob-based scan stays; the new context-first pass augments it).

---

## Architecture

### Flow — scaffolding a new project

```
User runs /structured-agentic-coding
  ↓
Skill Phase 0: Context gathering
  • Read README.md, CLAUDE.md, docs/*.md
  • Build a mental model (runtime, package manager, stated conventions)
  ↓
Skill Phase 1: Profile recommendation
  • Systematic scan (Glob package.json, *.csproj, docker-compose, graphql.config.*)
  • Cross-check against context hints
  • Recommend profile with rationale; user confirms or overrides
  ↓
User answers 4 fixed questions: PREFIX, PROFILE, SCOPE, PROJECT_DESC
  ↓
Skill Phase 2: Load profiles/<name>/variables.json
  • Run each variable's detect strategy
  • Apply context-inferred defaults where hints match
  • Present confirmation table (values labeled detected / inferred / defaulted)
  ↓
scaffold.sh runs:
  • Concatenate fragments (_core + _be-section + _fe-section) per SCOPE
  • Copy+replace profile-specific files
  • Generate manifest
```

### Flow — upgrade of an existing project

```
User runs /upgrade-agentic-coding
  ↓
Read manifest → compare version
  ↓
Step 1b (ALWAYS active): re-scan repo for profile migration opportunity
  • Run context+systematic detection fresh
  • Compare recommended profile vs manifest's profile
  • If divergent, prompt user with migration option (can decline → standard upgrade)
  ↓
If migration accepted:
  • Carry over compatible placeholders (PREFIX, PROJECT_NAME, PROJECT_DESC)
  • Re-detect stack-specific variables from new profile manifest
  • Re-emit scaffold, preserving user-modified files (hash diff)
  • Rewrite manifest with new profile + version
If declined or no migration applicable:
  • Standard category-selective upgrade (current behavior)
```

### Components

| Component | Location | Responsibility |
|---|---|---|
| `scaffold.sh` (refactor) | `structured-agentic-coding-plugin/scripts/scaffold.sh` | SCOPE flag, manifest loader, fragment concatenation |
| `variables.json` schema | `docs/variables-schema.md` (new) | Contract for detection + scope + conditionals |
| Template fragments | `.claude/scaffold/base/claude/`, `.../agents-md/`, `.../settings/` | Composable pieces `_core` + `_fe-section` + `_be-section` |
| Profile `nestjs-query-be` | `.claude/scaffold/profiles/nestjs-query-be/` | 5 agents, ~45 rules, ~10 scans, manifest, claude-section |
| Profile `refine-nestjs-query-fe` | `.claude/scaffold/profiles/refine-nestjs-query-fe/` | 5 agents, ~45 rules, ~12 scans, manifest, claude-section, graphql-codegen-sync command |
| Smoke test harness | `scripts/smoke-test.sh` + `scripts/fixtures/` + `scripts/baselines/` | Scaffold into /tmp, diff vs baseline, byte-identity check |
| Skill updates | `skills/structured-agentic-coding/SKILL.md`, `skills/upgrade-agentic-coding/SKILL.md`, `scripts/upgrade.sh` | Context-first detection, always-active profile migration |

### Key implementation details

**`variables.json` schema** (full contract):

```json
{
  "profile": "nestjs-query-be",
  "scope": "be",
  "context_hints": [
    { "file": "CLAUDE.md", "grep": "bun", "implies": { "BE_RUNTIME": "bun" } },
    { "file": "README.md", "grep": "Firestore", "implies": { "FIREBASE_SCOPE": "firestore" } }
  ],
  "variables": [
    {
      "key": "BE_BUILD",
      "scope": "be",
      "required": true,
      "detect": [
        { "type": "package-json-script", "script": "build", "runtime_prefix": true },
        { "type": "static", "value": "bun run build" }
      ]
    },
    {
      "key": "DB_MANAGED",
      "scope": "be",
      "type": "boolean",
      "detect": [{ "type": "glob-absent", "pattern": "**/docker-compose*.yml" }]
    },
    {
      "key": "DB_START",
      "scope": "be",
      "required_if": { "DB_MANAGED": false },
      "detect": [{ "type": "docker-compose-service", "service_hint": "postgres|mysql|mariadb" }]
    }
  ]
}
```

Supported `detect.type` values: `package-json-script`, `glob-present`, `glob-absent`, `regex-in-file`, `docker-compose-service`, `static`, `context-inferred`.

**Detection order** (enforced by the skill):
1. **Context pass** — read README.md, CLAUDE.md, docs/*.md to build a set of "declared facts" that override or qualify systematic detection.
2. **Systematic pass** — apply each variable's `detect[]` strategies in order until one resolves; fall back to `default` or `TODO: configure`.
3. **Confirmation pass** — present table to the user marking each value as `detected`, `inferred` (from context_hints), or `defaulted`. User confirms or corrects.

**Fragment concatenation logic in `scaffold.sh`**:

```bash
case "$SCOPE" in
  fullstack) concat _core + _be-section + _fe-section ;;
  be)        concat _core + _be-section ;;
  fe)        concat _core + _fe-section ;;
esac
# Write to TARGET_DIR/CLAUDE.md then run placeholder replacement
```

Fragments must be designed so that in fullstack mode the concatenated output is **byte-identical** to the current `base/CLAUDE.md`. This invariant is enforced by the smoke test harness via `diff -r` against committed baselines.

---

## Caution Areas

1. **Byte-identity for angular-dotnet** — Risk: moving placeholders, changing newlines, or reordering sections produces a diff vs the current output. Mitigation: smoke test scaffolds with fixed parameters against a fixture and compares to a committed baseline under `scripts/baselines/angular-dotnet-fullstack.snapshot/`. Any diff fails the test.

2. **Fragment boundaries** — Risk: bad cuts produce orphan sections in `CLAUDE.md`. Mitigation: each fragment has an explicit contract (head/tail comment markers inside the fragment file) and a validation script that checks required H2 headings are present after concatenation.

3. **Always-active profile migration in upgrade** — Risk: adds ~5s to every upgrade; could be noisy if users upgrade frequently. Mitigation: only prompt when the re-scan genuinely recommends a different profile (strict match criteria); silent pass-through otherwise. No prompt = standard upgrade path, zero interruption.

4. **Profile migration destructiveness** — Risk: migrating `base` → `nestjs-query-be` could overwrite user edits. Mitigation: migrate-profile mode is append-only for new files; any file with hash mismatch is always preserved and user sees the skip list before apply.

5. **pg-boss vs BullMQ** — Risk: `nestjs-query-be` rules flagging BullMQ as invalid when the profile may be adopted by teams on BullMQ. Mitigation: rule written as "if using `@nestjs/bull` or `@nestjs/bullmq`, justification comment required" (severity `warn`, not `error`); documented in `anti-patterns-profile.md`.

6. **Refine.dev assumption in FE profile** — Risk: rules coupled to Refine make the profile unusable for React+Vite without Refine. Mitigation: the profile name `refine-nestjs-query-fe` makes the constraint explicit; projects without Refine should use `base` (documented in recommendation logic).

7. **Test enforcement before harness is installed** — Risk: rules that require `*.spec.ts` files fail immediately on SPS (no tests yet). Mitigation: presence-check rules ship at severity `info` initially; flipping to `error` later is a trivial rule edit, not a blocker for this masterplan.

---

## Implementation Phases

### Phase 1 — Scaffold foundation (SCOPE flag + variables.json + smoke test)

Sequential. Foundation for everything else.

#### Tasks

- [ ] **Task 1.1 — Design variables.json schema**
  - Scope: `mixed`
  - Files: `docs/variables-schema.md` (new)
  - Details: |
      WHAT: Full schema document for per-profile `variables.json`.
      HOW: Describe every field (`key`, `scope`, `type`, `required`, `required_if`, `detect[]`, `default`, `label`) and every `detect.type` value with concrete examples (simple variable, conditional variable, context-inferred variable). Include a "migration from hardcoded" section explaining how the current hardcoded skill variables map to the new schema.
      GUARD: Documentation only — no loader code at this step. The schema must be complete enough for Task 1.2 to implement against.
  - Depends on: (none)
  - Bloom: L5
  - Accept: |
      - [ ] Document enumerates every `detect.type` supported
      - [ ] At least 3 worked examples (simple / conditional / context-inferred)
      - [ ] Migration section maps every current angular-dotnet variable to the new schema

- [ ] **Task 1.2 — Refactor scaffold.sh: SCOPE flag + manifest loader + fragment concat function**
  - Scope: `mixed`
  - Files: `structured-agentic-coding-plugin/scripts/scaffold.sh`
  - Details: |
      WHAT: Add `SCOPE=fe|be|fullstack` flag (default `fullstack`). Add `load_profile_variables()` that reads `profiles/<name>/variables.json` via `jq`. Add `concat_fragments()` function switching on SCOPE.
      HOW: Keep current CLI signature backward-compatible — if SCOPE not provided, behave exactly as today. Variables come from: (1) CLI KEY=VALUE args (highest priority), (2) manifest defaults (fallback), (3) detection results passed by the skill.
      GUARD: Do NOT touch template files yet — fragmentation lands in Phase 2. `scaffold.sh` must still produce identical output for `angular-dotnet` and `base` fullstack when called with current args.
  - Depends on: 1.1
  - Bloom: L5
  - Accept: |
      - [ ] `bash scaffold.sh <current args>` produces output identical to pre-refactor
      - [ ] `bash scaffold.sh <args> SCOPE=be` excludes FE directory structures from output
      - [ ] `load_profile_variables()` reads manifest if present, falls back gracefully otherwise

- [ ] **Task 1.3 — Smoke test harness (run BEFORE Task 1.2 to capture baselines)**
  - Scope: `mixed`
  - Files: `scripts/smoke-test.sh` (new), `scripts/fixtures/base-fullstack/` (new), `scripts/fixtures/angular-dotnet-fullstack/` (new), `scripts/baselines/` (new directory, committed)
  - Details: |
      WHAT: Bash script that runs `scaffold.sh` against fixture mini-projects (package.json / *.csproj / docker-compose.yml stubs), saves output to tmpdir, then runs `diff -r` against a committed baseline under `scripts/baselines/`. Flag `--regen` rewrites baselines.
      HOW: Start with two fixtures (`base-fullstack`, `angular-dotnet-fullstack`). More added in later phases. CRITICAL: generate baselines from the pre-refactor state before starting Task 1.2 — the committed baselines represent ground truth.
      GUARD: Baseline commit must land in the same PR branch before any scaffold.sh changes. If we refactor first, we lose the ground truth.
  - Depends on: (must run BEFORE 1.2)
  - Bloom: L4
  - Accept: |
      - [ ] `bash scripts/smoke-test.sh` passes on pre-refactor state
      - [ ] `bash scripts/smoke-test.sh --regen` regenerates baselines cleanly
      - [ ] Baselines committed to the repo

#### Commit: `feat(scaffold): add SCOPE flag, variables.json loader, smoke-test harness`

---

### Phase 2 — Fragment base templates

Break the monolithic templates while preserving fullstack byte-identity.

#### Tasks

- [ ] **Task 2.1 — Split base/CLAUDE.md into fragments**
  - Scope: `mixed`
  - Files: `structured-agentic-coding-plugin/.claude/scaffold/base/claude/_core.md` (new), `.../claude/_fe-section.md` (new), `.../claude/_be-section.md` (new), `.../base/CLAUDE.md` (remove)
  - Details: |
      WHAT: Split the current 79-line template into three fragments. `_core` contains: header, Code Graph section, Static Analysis section, Coding Standards section, Dynamic Agent Discovery section, Masterplan System section, Git Conventions section. `_fe-section` contains FE-specific lines (agent dir FE, FE commands, E2E). `_be-section` contains BE-specific lines (agent dir BE, BE commands, DB, migrations).
      HOW: Design header levels and blank lines so the concatenation `_core + _be-section + _fe-section` in fullstack mode is byte-identical to the current `base/CLAUDE.md`. Use HTML-comment markers inside fragments to delimit intended boundaries (strippable if needed).
      GUARD: The base-fullstack smoke test must pass with a zero-byte diff after concatenation.
  - Depends on: 1.2, 1.3
  - Bloom: L5
  - Accept: |
      - [ ] Three fragment files present
      - [ ] `scripts/smoke-test.sh` passes `base-fullstack` (empty diff)
      - [ ] All current placeholders (`__BE_DIR__`, `__FE_DIR__`, `__PREFIX__`, `__BE_RUN__`, etc.) appear in the correct fragment

- [ ] **Task 2.2 — Split base/AGENTS.md into fragments**
  - Scope: `mixed`
  - Files: `.../base/agents-md/_core.md` (new), `.../agents-md/_fe-section.md` (new), `.../agents-md/_be-section.md` (new), `.../base/AGENTS.md` (remove)
  - Details: |
      WHAT: Current AGENTS.md has no dedicated FE/BE sections (only root agents). For retro-compat, `_core` contains all current content; `_fe-section` and `_be-section` start empty and get populated by profile-specific sections in Phase 3-5.
      HOW: Minimal initial split — the value lands when profiles contribute section overlays.
      GUARD: Fullstack output byte-identical.
  - Depends on: 1.2, 1.3
  - Bloom: L4
  - Accept: |
      - [ ] Fragment files present
      - [ ] Smoke test passes on `base-fullstack`

- [ ] **Task 2.3 — Handle base/settings.json per SCOPE**
  - Scope: `mixed`
  - Files: `.../base/settings/_core.json` (new), `.../base/settings.json` (remove)
  - Details: |
      WHAT: Current `settings.json` is small (one SessionStart hook). No real fragmentation needed yet — only a `_core.json` matching the current file. Structure is ready for future scope-specific hooks.
      HOW: Copy current content into `_core.json`; `scaffold.sh` copies it as-is into the target as `settings.json`.
      GUARD: No hook regression.
  - Depends on: 1.2
  - Bloom: L2
  - Accept: |
      - [ ] `_core.json` present with identical content
      - [ ] `scaffold.sh` places it as `.claude/settings.json` in the target project

- [ ] **Task 2.4 — Update scaffold.sh to consume fragments**
  - Scope: `mixed`
  - Files: `structured-agentic-coding-plugin/scripts/scaffold.sh`
  - Details: |
      WHAT: Replace the section that copies `base/CLAUDE.md`, `base/AGENTS.md`, `base/settings.json` with fragment-concat logic implemented in Task 1.2.
      HOW: Remove the three current `copy_and_replace` calls and substitute with parameterized `concat_fragments` calls driven by SCOPE.
      GUARD: Smoke test must continue to pass.
  - Depends on: 2.1, 2.2, 2.3
  - Bloom: L4
  - Accept: |
      - [ ] `base-fullstack` smoke test passes
      - [ ] Simulated `SCOPE=be` run produces a `CLAUDE.md` without the FE section (manual inspection)

#### Commit: `refactor(scaffold): fragment base templates with SCOPE-aware concatenation`

---

### Phase 3 — Migrate angular-dotnet to the new manifest system

#### Tasks

- [ ] **Task 3.1 — Create profiles/angular-dotnet/variables.json**
  - Scope: `mixed`
  - Files: `structured-agentic-coding-plugin/.claude/scaffold/profiles/angular-dotnet/variables.json` (new)
  - Details: |
      WHAT: Extract the variable set currently hardcoded in the skill (BE_SLN, BE_API_PROJECT, BE_NAMESPACE, FE_DIR, BE_DIR, FE_SERVE, FE_BUILD, FE_TEST, FE_FORMAT, FE_LINT, BE_BUILD, BE_TEST, BE_RUN, BE_FORMAT, DB_START, MIGRATION, E2E_CMD) into a manifest conforming to the schema from Task 1.1.
      HOW: Replicate 1:1 the detection strategies described in the current `structured-agentic-coding/SKILL.md` Phase 2. Include `context_hints` for Nx monorepo (detected via `nx.json`).
      GUARD: Variable list must be identical in semantics to today — zero silent behavior change.
  - Depends on: 1.1
  - Bloom: L4
  - Accept: |
      - [ ] variables.json validates against the schema from Task 1.1
      - [ ] Every variable currently used by angular-dotnet is represented
      - [ ] `angular-dotnet-fullstack` smoke test passes after wiring

- [ ] **Task 3.2 — Create profiles/angular-dotnet/claude-section.md**
  - Scope: `mixed`
  - Files: `.../profiles/angular-dotnet/claude-section.md` (new, possibly empty)
  - Details: |
      WHAT: Any extra `CLAUDE.md` lines specific to angular-dotnet (e.g., reference to `/openapi-sync`). If the base `_fe-section`/`_be-section` already cover everything, this file stays minimal or empty.
      HOW: Compare current CLAUDE.md output against base concat; add only the true delta.
      GUARD: Fullstack output stays byte-identical.
  - Depends on: 2.1, 3.1
  - Bloom: L4
  - Accept: |
      - [ ] File present (even if empty)
      - [ ] Smoke test passes

- [ ] **Task 3.3 — Remove angular-dotnet hardcodes from skill + scaffold.sh**
  - Scope: `mixed`
  - Files: `structured-agentic-coding-plugin/skills/structured-agentic-coding/SKILL.md`, `structured-agentic-coding-plugin/scripts/scaffold.sh`
  - Details: |
      WHAT: Strip hardcoded variable descriptions for angular-dotnet from `SKILL.md` Phases 2-3 — the skill now loads the chosen profile's `variables.json`. In `scaffold.sh`, remove the `if [[ "$PROFILE" == "angular-dotnet" ]]` special-case for manifest/placeholder handling; keep the profile-specific file-copy block (agents, rules, scans) which remains identical.
      HOW: The new SKILL.md flow: "Load variables.json from profile → run detection → present confirmation table → invoke scaffold.sh". Keep profile-specific detection hints as free-text hints the skill can reference, but not as hardcoded logic.
      GUARD: Skill output when profile is `angular-dotnet` must remain identical to pre-refactor.
  - Depends on: 3.1, 3.2
  - Bloom: L5
  - Accept: |
      - [ ] No hardcoded `BE_SLN` / `BE_NAMESPACE` / `BE_API_PROJECT` strings in `SKILL.md`
      - [ ] `angular-dotnet-fullstack` smoke test passes
      - [ ] Manual diff on a real angular-dotnet scaffold matches pre-refactor output

#### Commit: `refactor(angular-dotnet): migrate to manifest-driven scaffolding`

---

### Phase 4 — Profile `nestjs-query-be` (parallelizable with Phase 5)

#### Tasks

- [ ] **Task 4.1 — variables.json + claude-section.md**
  - Scope: `be`
  - Files: `.../profiles/nestjs-query-be/variables.json`, `.../profiles/nestjs-query-be/claude-section.md`
  - Details: |
      WHAT: Manifest with variables: PREFIX, PROJECT_NAME, PROJECT_DESC, BE_RUNTIME, BE_BUILD, BE_RUN, BE_TEST, BE_TEST_E2E, BE_FORMAT, BE_LINT, MIGRATION_RUN, MIGRATION_GENERATE, MIGRATION_REVERT, DB_MANAGED (bool), DB_START (required_if !DB_MANAGED), FIREBASE_EMULATOR, GRAPHQL_SCHEMA_OUT. context_hints for Bun, Firebase Auth, TypeORM via CLAUDE.md/README grep.
      HOW: DB_MANAGED uses `glob-absent` on `**/docker-compose*.yml`. FIREBASE_EMULATOR detects via `package-json-script` on `firebase:emulator:start`. claude-section adds reference to Firebase emulator and pg-boss usage.
      GUARD: Scope = `be`. Remove BE_SLN/BE_API_PROJECT/BE_NAMESPACE inherited from angular-dotnet — those do not apply.
  - Depends on: 1.1, 3.3
  - Bloom: L5
  - Accept: |
      - [ ] variables.json valid, 16+ variables
      - [ ] Simulated detection against `sps-app-backend` produces correct values
      - [ ] claude-section.md present

- [ ] **Task 4.2 — Agent: be-feature-developer**
  - Scope: `be`
  - Files: `.../profiles/nestjs-query-be/agents/backend/feature-developer.md`
  - Details: |
      WHAT: Agent definition for a NestJS feature developer. Model: sonnet, effort: medium.
      HOW: Mirror the structure of `angular-dotnet/backend/feature-developer.md` but target NestJS module anatomy: TypeORM entities + migrations, nestjs-query patterns (@FilterableField, CRUDResolver, assembler), guard chain (UserAuthGuard → RolesGuard → PartnerAssignedGuard), @Trim(), pg-boss jobs, Firebase Auth. Bash commands gated to `__BE_BUILD__`, `__BE_FORMAT__`, `__BE_TEST__`.
      GUARD: Tools: Read/Glob/Grep/Edit/Write/Bash. NEVER touch `src/schema.gql` (auto-generated). NEVER touch committed migrations. STOP-and-report when task scope requires out-of-scope edits.
  - Depends on: 4.1
  - Bloom: L5
  - Accept: |
      - [ ] File present with placeholders `__PROJECT_NAME__`, `__PREFIX__`, `__BE_BUILD__`, etc.
      - [ ] Sections: Context, Tools, Boundaries, Scope, How to Generate Code, Build and Format, Output, Budget
      - [ ] Protected paths documented (`src/schema.gql`, existing migrations)

- [ ] **Task 4.3 — Agent: be-code-reviewer**
  - Scope: `be`
  - Files: `.../profiles/nestjs-query-be/agents/backend/code-reviewer.md`
  - Details: |
      WHAT: Review agent that invokes scan playbooks, produces structured report with violation + fix suggestions.
      HOW: Mirror the angular-dotnet code-reviewer pattern. Rule ID prefix `BE-*` matches `be-rules.json` from Task 4.6. Invokes scans from `be-scans/`.
      GUARD: Read-only agent — no edits.
  - Depends on: 4.6
  - Bloom: L5
  - Accept: |
      - [ ] References `.claude/rules/be-rules.json`
      - [ ] Invokes scans from `be-scans/`

- [ ] **Task 4.4 — Agent: be-fixer**
  - Scope: `be`
  - Files: `.../profiles/nestjs-query-be/agents/backend/fixer.md`
  - Details: |
      WHAT: Applies fixes proposed by the reviewer. Receives violation list + context, applies surgical edits, re-runs build.
      HOW: Tool scope restricted to files named in the violation list. STOP-and-report when a fix needs refactoring outside task scope.
      GUARD: No broad refactors.
  - Depends on: 4.3
  - Bloom: L5
  - Accept: |
      - [ ] Tool scope limited to violation files
      - [ ] STOP-and-report clause present for out-of-scope fixes

- [ ] **Task 4.5 — Agents: be-test-writer + be-migration-reviewer**
  - Scope: `be`
  - Files: `.../profiles/nestjs-query-be/agents/domain/test-writer.md`, `.../domain/migration-reviewer.md`
  - Details: |
      test-writer: generates Jest `*.spec.ts` for feature modules, mocks TypeORM via `getRepositoryToken`, mocks pg-boss via `jest.mock`. Uses AAA structure (Arrange/Act/Assert).
      migration-reviewer: verifies new migrations have correct `down` reverse, descriptive naming, no silent table renames, FK with explicit `onDelete`.
      GUARD: Both agents STOP-and-report when uncertain about intent.
  - Depends on: 4.1
  - Bloom: L5
  - Accept: |
      - [ ] Both agent files present
      - [ ] Budget defined (15-30 turns each)

- [ ] **Task 4.6 — Rules: be-rules.json (~45 rules across 10 categories)**
  - Scope: `be`
  - Files: `.../profiles/nestjs-query-be/rules/be-rules.json`
  - Details: |
      Categories: BE-ARCH (module/feature structure), BE-TYPEORM (entities, migrations, no synchronize), BE-QUERY (nestjs-query FilterableField/Paging/CRUDResolver/Assembler), BE-AUTH (Firebase guard chain, token verify), BE-VAL (@Trim, FK existence validators, class-validator conventions), BE-QUEUE (pg-boss patterns), BE-API (REST thinness, Swagger env-gate), BE-SEC (Helmet, Turnstile, Throttler, AdminOnlyField), BE-CI (secrets parity cloudbuild.yaml vs deploy.yml, Dockerfile multi-stage), BE-TEST (Jest conventions, coverage floor, presence).
      HOW: Every rule has `id`, `name`, `category`, `layer`, `check`, `why` fields; optional `fix`.
      GUARD: Test-presence rules ship at severity `info` (will be raised when tests are installed).
  - Depends on: 4.1
  - Bloom: L5
  - Accept: |
      - [ ] 40+ rules total
      - [ ] ID format `BE-<CATEGORY>-NNN`
      - [ ] Every rule has id/name/category/layer/check/why

- [ ] **Task 4.7 — Scan playbooks: be-scans/*.md (~10 files)**
  - Scope: `be`
  - Files: `.../profiles/nestjs-query-be/scans/be-scans/architecture.md`, `typeorm.md`, `nestjs-query.md`, `auth.md`, `validation.md`, `queue.md`, `api.md`, `security.md`, `ci-secrets.md`, `testing.md`
  - Details: |
      WHAT: One playbook per rule category. Each maps to ~4-5 rules.
      HOW: Replicate angular-dotnet scan playbook format: What-to-check / Scan (Grep pattern + path) / True-positive criteria / False-positive criteria / Confirm / Severity.
      GUARD: Coverage — every rule in Task 4.6 must be covered by some scan step.
  - Depends on: 4.6
  - Bloom: L5
  - Accept: |
      - [ ] 10 files
      - [ ] Every rule from 4.6 covered by at least one scan step

- [ ] **Task 4.8 — anti-patterns-profile.md**
  - Scope: `be`
  - Files: `.../profiles/nestjs-query-be/anti-patterns-profile.md`
  - Details: |
      WHAT: Document known failure modes: `synchronize: true` in production, manual `@UseGuards` on GraphQL resolvers (global guards already apply), hand-edited `src/schema.gql`, explicit Id assignment on entities with auto-generated PK, test mocks that diverge from real migrations, BullMQ adopted without justification, Firebase token verify bypassed.
      HOW: Each anti-pattern has: trigger / why it's wrong / reference to rule IDs.
      GUARD: 8+ entries.
  - Depends on: 4.6
  - Bloom: L4
  - Accept: |
      - [ ] 8+ anti-patterns documented
      - [ ] Each references rule IDs from Task 4.6

- [ ] **Task 4.9 — Smoke test profile against sps-app-backend fixture**
  - Scope: `mixed`
  - Files: `scripts/fixtures/nestjs-query-be/` (new), `scripts/baselines/nestjs-query-be.snapshot/` (new)
  - Details: |
      WHAT: Minimal NestJS fixture (package.json with @nestjs/core, bun.lock stub, firebase.json, src/main.ts stub). Run scaffold against it, generate baseline snapshot, add to `smoke-test.sh`.
      HOW: Baseline is the ground truth for this profile going forward — any future change to the profile must update the baseline or fail the smoke test.
      GUARD: Dry-run mentally against real `sps-app-backend` — no unexpected unresolved placeholders.
  - Depends on: 4.1-4.8
  - Bloom: L4
  - Accept: |
      - [ ] Fixture scaffold produces all expected files
      - [ ] Smoke test passes
      - [ ] Mental dry-run on `sps-app-backend` reports no unexpected unresolved placeholders

#### Commit: `feat(profiles): add nestjs-query-be profile`

---

### Phase 5 — Profile `refine-nestjs-query-fe` (parallelizable with Phase 4)

#### Tasks

- [ ] **Task 5.1 — variables.json + claude-section.md**
  - Scope: `fe`
  - Files: `.../profiles/refine-nestjs-query-fe/variables.json`, `.../profiles/refine-nestjs-query-fe/claude-section.md`
  - Details: |
      WHAT: Variables: PREFIX, PROJECT_NAME, PROJECT_DESC, FE_RUNTIME (bun), FE_SERVE, FE_BUILD, FE_BUILD_STAGE, FE_FORMAT, FE_LINT, FE_LINT_FIX, FE_TYPECHECK, GRAPHQL_CODEGEN, GRAPHQL_SCHEMA_SRC (URL-or-path), FE_TEST (TODO until harness), E2E_CMD (TODO until harness).
      HOW: `GRAPHQL_SCHEMA_SRC` detection: `regex-in-file` against `graphql.config.ts` looking for introspection URL or file path; fallback to user input. context_hints: "Refine required" (grep `@refinedev/core` in package.json), "Bun required" (grep `bun.lock` presence or CLAUDE.md mention), "Zod v4" (grep `zod/v4` in any src file).
      GUARD: Scope = `fe`.
  - Depends on: 1.1, 3.3
  - Bloom: L5
  - Accept: |
      - [ ] variables.json valid, 12+ variables
      - [ ] claude-section references `/graphql-codegen-sync`

- [ ] **Task 5.2 — Agent: fe-feature-developer**
  - Scope: `fe`
  - Files: `.../profiles/refine-nestjs-query-fe/agents/frontend/feature-developer.md`
  - Details: |
      WHAT: Agent for React 19 + Refine 5 + nestjs-query client + shadcn/ui + Tailwind 4 + Zod v4.
      HOW: Enforcements encoded in agent prompt: `from 'zod/v4'` import, `useTranslation` from `@refinedev/core` (never `react-i18next` directly), `import.meta.env.VITE_*` for env access. Protected paths: `src/graphql/*` (auto-generated), `patches/`. Commands gated: FE_BUILD, FE_FORMAT, FE_LINT, FE_TYPECHECK.
      GUARD: Tools: Read/Glob/Grep/Edit/Write/Bash. Bash restricted to build/format/lint/typecheck/codegen.
  - Depends on: 5.1
  - Bloom: L5
  - Accept: |
      - [ ] Refine resource/dataProvider/authProvider patterns documented
      - [ ] Protected paths enforcement present
      - [ ] Commands placeholders present

- [ ] **Task 5.3 — Agent: fe-code-reviewer**
  - Scope: `fe`
  - Files: `.../profiles/refine-nestjs-query-fe/agents/frontend/code-reviewer.md`
  - Details: |
      WHAT: Mirror `be-code-reviewer` but for FE. Invokes `fe-scans/`.
      GUARD: Read-only.
  - Depends on: 5.6
  - Bloom: L5
  - Accept: |
      - [ ] References `.claude/rules/fe-rules.json`
      - [ ] Invokes scans from `fe-scans/`

- [ ] **Task 5.4 — Agent: fe-fixer**
  - Scope: `fe`
  - Files: `.../profiles/refine-nestjs-query-fe/agents/frontend/fixer.md`
  - Depends on: 5.3
  - Bloom: L4
  - Accept: |
      - [ ] Restricted file scope
      - [ ] STOP-and-report out of scope

- [ ] **Task 5.5 — Agents: fe-test-writer + fe-resource-generator + graphql-codegen-sync**
  - Scope: `fe`
  - Files: `.../profiles/refine-nestjs-query-fe/agents/domain/test-writer.md`, `.../domain/resource-generator.md`, `.../domain/graphql-codegen-sync.md`
  - Details: |
      test-writer: Vitest + React Testing Library. Mocks GraphQL via MSW (documented as best practice even though SPS harness arrives later).
      resource-generator: scaffolds new Refine resources (list/create/edit/show pages + GraphQL operations + types scaffold).
      graphql-codegen-sync (domain agent): wraps `bun run codegen`. Optionally updates `graphql.config.ts` schema source (URL or path) before running codegen.
      GUARD: None of these agents touch `src/graphql/types.ts` directly — they invoke codegen.
  - Depends on: 5.1
  - Bloom: L5
  - Accept: |
      - [ ] Three agent files present
      - [ ] resource-generator includes a Refine page template reference

- [ ] **Task 5.6 — Rules: fe-rules.json (~45 rules)**
  - Scope: `fe`
  - Files: `.../profiles/refine-nestjs-query-fe/rules/fe-rules.json`
  - Details: |
      Categories: FE-REFINE (provider wiring, useTranslation source, resource definition), FE-GQL (inline gql tag conventions, TypedDocumentNode, codegen freshness), FE-FORM (react-hook-form + Zod v4, error mapping), FE-UI (shadcn + Tailwind CSS variables, Emotion secondary status), FE-AUTH (Firebase token injection in data-provider), FE-I18N (key prefix, namespace conventions), FE-ENV (import.meta.env.VITE_*), FE-PROT (protected paths enforcement), FE-BUN (Bun-only package manager), FE-TEST (Vitest conventions, coverage floor, presence).
      GUARD: Test-presence rules at severity `info` initially.
  - Depends on: 5.1
  - Bloom: L5
  - Accept: |
      - [ ] 40+ rules
      - [ ] ID format `FE-<CATEGORY>-NNN`

- [ ] **Task 5.7 — Scan playbooks: fe-scans/*.md (~12 files)**
  - Scope: `fe`
  - Files: `.../profiles/refine-nestjs-query-fe/scans/fe-scans/refine-providers.md`, `graphql-operations.md`, `codegen-freshness.md`, `forms-zod.md`, `ui-theming.md`, `auth-firebase.md`, `i18n.md`, `env-vars.md`, `protected-paths.md`, `package-manager.md`, `access-control.md`, `testing.md`
  - Depends on: 5.6
  - Bloom: L5
  - Accept: |
      - [ ] 12 files
      - [ ] All rules from 5.6 covered

- [ ] **Task 5.8 — Command `/graphql-codegen-sync`**
  - Scope: `fe`
  - Files: `.../profiles/refine-nestjs-query-fe/commands/graphql-codegen-sync.md`
  - Details: |
      WHAT: Slash command that invokes the `graphql-codegen-sync` domain agent. Optional flag `--schema-src <url|path>` to update `graphql.config.ts` before codegen.
      HOW: Wraps, does not replace, the existing `bun run codegen`. Documents both modes (URL introspection + local path with symlink to BE repo).
      GUARD: Does not edit auto-generated types directly.
  - Depends on: 5.5
  - Bloom: L4
  - Accept: |
      - [ ] File present
      - [ ] Both modes documented (URL + path)

- [ ] **Task 5.9 — anti-patterns-profile.md**
  - Scope: `fe`
  - Files: `.../profiles/refine-nestjs-query-fe/anti-patterns-profile.md`
  - Details: |
      WHAT: `from 'zod'` instead of `zod/v4`, `useTranslation` from `react-i18next` instead of `@refinedev/core`, manual edit of `src/graphql/types.ts`, npm/yarn/pnpm commands instead of bun, Emotion as primary styling, `process.env.*` instead of `import.meta.env.VITE_*`, skipping TanStack Query for client-side server state.
      GUARD: 8+ entries with rule ID references.
  - Depends on: 5.6
  - Bloom: L4
  - Accept: |
      - [ ] 8+ anti-patterns
      - [ ] Rule ID references present

- [ ] **Task 5.10 — Smoke test profile against sps-app-frontend fixture**
  - Scope: `mixed`
  - Files: `scripts/fixtures/refine-nestjs-query-fe/`, `scripts/baselines/refine-nestjs-query-fe.snapshot/`
  - Depends on: 5.1-5.9
  - Bloom: L4
  - Accept: |
      - [ ] Scaffold against a clean fixture produces expected output
      - [ ] Smoke test passes
      - [ ] Mental dry-run on `sps-app-frontend` reports no unexpected unresolved placeholders

#### Commit: `feat(profiles): add refine-nestjs-query-fe profile with graphql-codegen-sync command`

---

### Phase 6 — Skills update (context-first detection + always-active profile migration)

#### Tasks

- [ ] **Task 6.1 — Refactor `structured-agentic-coding/SKILL.md`**
  - Scope: `mixed`
  - Files: `structured-agentic-coding-plugin/skills/structured-agentic-coding/SKILL.md`
  - Details: |
      WHAT: Add Phase 0 "Context gathering" (read README.md, CLAUDE.md, docs/*.md). Update Phase 1 with profile recommendation logic including the new profiles. Add SCOPE question. Remove hardcoded variables (now come from `variables.json`). Add Phase 2b "Load profile manifest + run detection". Confirmation table is now generated from the manifest, not hardcoded.
      HOW: Full rewrite. Structure: Phase 0 context → Phase 1 profile pick (3 fixed questions + SCOPE) → Phase 2 manifest load → Phase 3 detection + confirmation → Phase 4 scaffold invocation → Phase 5 CODEMAP (unchanged) → Phase 6 report (unchanged).
      GUARD: Behavior for `base` and `angular-dotnet` must remain compatible with current output.
  - Depends on: 1.2, 3.3, 4.1, 5.1
  - Bloom: L6
  - Accept: |
      - [ ] Phase 0 context-first pass present and described
      - [ ] 4 fixed questions (name, profile, scope, desc)
      - [ ] Dynamic variable loading documented
      - [ ] All 4 profiles referenced (base, angular-dotnet, nestjs-query-be, refine-nestjs-query-fe)
      - [ ] Updated recommendation logic

- [ ] **Task 6.2 — Refactor `upgrade-agentic-coding/SKILL.md` + `scripts/upgrade.sh` (always-active profile migration)**
  - Scope: `mixed`
  - Files: `structured-agentic-coding-plugin/skills/upgrade-agentic-coding/SKILL.md`, `structured-agentic-coding-plugin/scripts/upgrade.sh`
  - Details: |
      WHAT: Add Step 1b "Profile migration opportunity detection" that runs **always** (no opt-in flag). After reading the manifest, re-scan the repo (context + systematic) and check whether a different profile now matches better. If divergent, prompt the user; if aligned, silent pass-through.
      HOW: Migration mode copies compatible placeholders (PREFIX, PROJECT_NAME, PROJECT_DESC carry over); re-detects stack-specific variables from the new manifest; re-emits scaffold preserving user-modified files (hash diff → always skip unless user says force). `upgrade.sh` learns a flag `--migrate-profile <new-profile>` that the skill invokes after user confirmation.
      GUARD: Migration prompt shown ONLY when re-scan recommendation differs from manifest's current profile. User must explicitly confirm before apply — decline falls back to standard upgrade. Detection adds ~5s to every upgrade run; documented as expected overhead.
  - Depends on: 6.1
  - Bloom: L6
  - Accept: |
      - [ ] Step 1b documented with worked example
      - [ ] `upgrade.sh` supports `--migrate-profile <new>` flag
      - [ ] Compatible placeholders enumerated (PREFIX, PROJECT_NAME, PROJECT_DESC)
      - [ ] Manual scenario: `base` project scanned as `nestjs-query-be` triggers migration prompt; `base` project that stays generic triggers silent pass-through

#### Commit: `feat(skills): context-first detection + always-active profile migration`

---

### Phase 7 — Docs + release

#### Tasks

- [ ] **Task 7.1 — Update README.md**
  - Scope: `mixed`
  - Files: `README.md`
  - Details: |
      WHAT: Update "Supported Stacks" table with the 2 new profiles. Update "Features" table counts (agents/rules/scans). Add "Profile selection" section with a decision tree. Document `/graphql-codegen-sync`.
      GUARD: Consistency with CHANGELOG and plugin.json versions.
  - Depends on: 4, 5, 6
  - Bloom: L4
  - Accept: |
      - [ ] All 4 profiles in the table
      - [ ] Decision tree clear
      - [ ] `/graphql-codegen-sync` documented

- [ ] **Task 7.2 — Update CHANGELOG.md + bump version**
  - Scope: `mixed`
  - Files: `structured-agentic-coding-plugin/CHANGELOG.md`, `structured-agentic-coding-plugin/.claude-plugin/plugin.json`
  - Details: |
      WHAT: Add `[4.3.0]` entry listing: profiles `nestjs-query-be` + `refine-nestjs-query-fe`, SCOPE flag, `variables.json` manifest system, template fragmentation, context-first detection, always-active profile migration in upgrade.
      GUARD: Semver rationale — minor bump (retro-compat preserved).
  - Depends on: 7.1
  - Bloom: L2
  - Accept: |
      - [ ] `[4.3.0]` entry present and complete
      - [ ] `plugin.json` version set to `4.3.0`

- [ ] **Task 7.3 — End-to-end dry-run on SPS repos**
  - Scope: `mixed`
  - Files: `docs/reports/sps-scaffold-dry-run.md` (new)
  - Details: |
      WHAT: Scaffold (into a temporary copy, not directly on the repos) `sps-app-backend` with `nestjs-query-be` + `SCOPE=be`, and `sps-app-frontend` with `refine-nestjs-query-fe` + `SCOPE=fe`. Document: detected variables, variables that required user input, unresolved placeholders, scaffolded file list, applicable rules/scans.
      GUARD: No write to real SPS repos. Produces a report only.
  - Depends on: 4.9, 5.10, 6.1
  - Bloom: L5
  - Accept: |
      - [ ] Report includes a table of detected vs TODO variables
      - [ ] No unexpected unresolved placeholders
      - [ ] Generated file list matches fixture smoke test

#### Commit: `chore(release): 4.3.0 — stack-specific profiles for NestJS + Refine`

---

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Profile names | `nestjs-query-be`, `refine-nestjs-query-fe` | Explicit constraints (nestjs-query + Refine). Teams without those use `base`. |
| Template fragmentation | Option 3c — concatenation `_core + _be + _fe` | Zero duplication, byte-identity fullstack is enforceable |
| Agent directory layout | Symmetric (`agents/backend/`, `agents/domain/`) | Consistent with `angular-dotnet` |
| `variables.json` manifest | Per-profile, with `context_hints` | Eliminates hardcoded variables in the skill; makes new profiles cheap to add |
| Detection order | Context-first (README/CLAUDE.md) before systematic glob | Declared conventions override or qualify what glob finds (e.g., Zod v4 gotcha) |
| `angular-dotnet` migration | Option A — full migration to manifest system | No dual-path tech debt; byte-identity verified by smoke test |
| Upgrade path for profile switches | Always-active migration check in `/upgrade-agentic-coding` | Unified UX; user confirms before apply; ~5s overhead accepted |
| Plugin version bump | 4.3.0 minor | Retro-compat preserved |
| Test strategy | Smoke test baseline-based with fixtures | Byte-identity is a strong claim requiring automated verification |
| Test enforcement (no harness yet) | Severity `info` on presence checks; raise to `error` later | Do not block scaffold today; rules ready when tests land |

---

## Success Criteria

- [ ] `/structured-agentic-coding` on `sps-app-backend` with profile `nestjs-query-be` + `SCOPE=be` produces a scaffold with no unexpected unresolved placeholders
- [ ] Same on `sps-app-frontend` with `refine-nestjs-query-fe` + `SCOPE=fe`
- [ ] All four smoke tests pass: `base-fullstack`, `angular-dotnet-fullstack`, `nestjs-query-be`, `refine-nestjs-query-fe` (byte-identity guaranteed for the first two)
- [ ] Upgrading a `base` project whose re-scan recommends `nestjs-query-be` prompts a migration; user can decline and get standard upgrade
- [ ] `/graphql-codegen-sync` in the FE profile successfully invokes `bun run codegen` without errors
- [ ] README, CHANGELOG, plugin.json aligned at 4.3.0
- [ ] No regression in `angular-dotnet` scaffolding verified by smoke test
