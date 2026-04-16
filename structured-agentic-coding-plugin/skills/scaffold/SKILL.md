---
name: scaffold
description: Scaffold a complete agent-driven development infrastructure into the current project — agents, rules, scan playbooks, masterplan workflows, and documentation templates. Use when the user says scaffold, set up, initialize, bootstrap agentic coding, install the structure, or asks to add the structured-agentic-coding scaffold to a project.
---

# Structured Agentic Coding — Project Scaffolding

Scaffold a complete agentic coding infrastructure into the current project. This creates the `.claude/` directory with agents, rules, commands, templates, and a root `CLAUDE.md` — everything needed for structured, agent-driven development.

## Profiles

- **base** — Framework-agnostic core: masterplan system, doc enforcer, research / impact agents, templates, commands. Works with any tech stack. **Use this when the project does NOT match a specialized profile.**
- **angular-dotnet** — Base + Angular + Nx + .NET Clean Architecture + PostgreSQL / EF Core + Playwright. Fullstack. **Use this ONLY when the project uses BOTH Angular (frontend) AND .NET C# (backend).** Angular + non-.NET backend = `base`.
- **nestjs-query-be** — Base + NestJS 11 + TypeORM + `@ptc-org/nestjs-query-*` + Firebase Auth + pg-boss + Jest + Bun. **Use this ONLY when the backend is NestJS with the nestjs-query GraphQL pattern.** NestJS without nestjs-query = `base`.
- **refine-nestjs-query-fe** — Base + React 19 + Vite + Refine.dev 5 + `@refinedev/nestjs-query` + shadcn/ui + Tailwind 4 + Firebase Auth + Zod v4 + Bun. **Use this ONLY when the frontend uses Refine.dev with the nestjs-query GraphQL client.** React without Refine = `base`.

## Scaffold Source

Templates live in `.claude/scaffold/` relative to wherever this skill is installed:

```
.claude/scaffold/
├── base/                          # Always scaffolded
│   ├── agents/codebase/           # Masterplan, doc-enforcer
│   ├── agents/domain/             # Research, impact analyst
│   ├── commands/                  # masterplan, rebuild-graph
│   ├── templates/                 # ARCHITECTURE + GUIDELINES templates
│   ├── claude/                    # CLAUDE.md fragments (_core, _be-section, _fe-section)
│   ├── agents-md/                 # AGENTS.md fragments
│   ├── settings/                  # settings.json fragment
│   └── anti-patterns.md           # Anti-patterns starter
└── profiles/<profile>/            # Profile-specific overlay
    ├── variables.json             # Detect strategies for placeholder values
    ├── claude-section.md          # Profile overlay appended to CLAUDE.md
    ├── agents/backend/            # BE agents (if profile has a backend)
    ├── agents/frontend/           # FE agents (if profile has a frontend)
    ├── agents/domain/             # Stack-specific cross-cutting agents
    ├── scans/be-scans/            # Backend scan playbooks
    ├── scans/fe-scans/            # Frontend scan playbooks
    ├── rules/                     # be-rules.json / fe-rules.json
    ├── commands/                  # Profile-specific slash commands
    └── anti-patterns-profile.md   # Stack-specific anti-patterns
```

## Procedure

### Phase 0 — Context gathering (read declared facts FIRST)

Before any systematic glob scan, read the high-signal project documentation to build a mental model of the declared conventions. Users often document non-obvious stack choices (e.g., "Bun required", "Zod v4 only") in prose that no glob can find.

Read, in this order:

1. `README.md` at the project root — stack overview, runtime, conventions
2. `CLAUDE.md` at the project root — explicit rules for AI assistants
3. `docs/*.md` (if present) — architecture, guidelines, decisions

From these extract "declared facts":
- Package manager / runtime (bun vs node vs deno)
- Framework version constraints (e.g., Refine 5, NestJS 11, Angular 17+)
- Special library choices (e.g., `zod/v4`, pg-boss, MSW, TanStack Query)
- Protected paths (e.g., `src/graphql/*.ts` auto-generated, `patches/`)
- Build / CI constraints (e.g., "only run in Cloud Build")

Hold these facts in mind — they inform profile recommendation (Phase 1) AND populate context-inferred variable defaults (Phase 2).

### Phase 1 — Profile recommendation (silent scan + user choice)

Quick-scan the project to determine the correct profile BEFORE asking the user.

Run these checks silently:
- `Glob("**/package.json")` — read dependencies to detect frameworks
- `Glob("**/*.csproj")` / `Glob("**/*.sln")` — detect .NET
- `Glob("**/graphql.config.*")` — detect GraphQL codegen setup
- `Glob("**/bun.lock")` / `Glob("**/bun.lockb")` — detect Bun

**Profile selection logic:**
- `@angular/core` AND `.csproj`/`.sln` → recommend **angular-dotnet**
- `@nestjs/core` AND `@ptc-org/nestjs-query-graphql` → recommend **nestjs-query-be**
- `react` + `vite` + `@refinedev/core` + `@refinedev/nestjs-query` → recommend **refine-nestjs-query-fe**
- Otherwise → recommend **base**

Cross-check against Phase 0 facts. If README/CLAUDE.md explicitly names a framework not detected in package.json (e.g., monorepo with nested apps), use that as a tiebreaker.

**Ask the user these 4 questions (all at once), presenting your recommendation:**

1. **Project name** — `PREFIX`. Lowercase kebab-case. Used for agent filename prefix and display name derivation.
   - Example: `sps-app-backend` → agents named `sps-app-backend-masterplan-architect.md`

2. **Profile** — which of the four profiles? Present your recommendation with a one-line rationale. User can override.

3. **Scope** — `SCOPE=fe|be|fullstack`. Default:
   - `angular-dotnet` profile → `fullstack`
   - `nestjs-query-be` profile → `be`
   - `refine-nestjs-query-fe` profile → `fe`
   - `base` profile → ask (typically `fullstack` unless repo clearly lacks one side)

4. **Project description** — one sentence for CLAUDE.md header.

Wait for answers before proceeding.

### Phase 2 — Load manifest + run detection

Load `profiles/<profile>/variables.json` from the chosen profile's scaffold directory.

```bash
find ~/.claude/plugins -name "variables.json" -path "*<profile>*" | head -1
```

Parse the manifest (see `docs/variables-schema.md` for the full schema). For each variable:

1. **Context pass** — apply `context_hints` entries against README / CLAUDE.md / docs (already read in Phase 0). Set `FACTS[key] = value` for each matching hint's `implies`.
2. **Systematic pass** — walk the variable's `detect[]` array in order:
   - `package-json-script` — read script from `package.json`, prefix with runtime (`bun run` or `npm run`) if `runtime_prefix: true`
   - `glob-present` / `glob-absent` — Glob check
   - `glob-first-path` — Glob and return the first match's path
   - `regex-capture-from-files` — Grep with capture group
   - `docker-compose-service` — parse compose files for service hint, emit `docker compose -f <path> up -d`
   - `regex-in-file` — Grep in a specific file
   - `from-variable` — expand `{VAR}` tokens in a template using already-resolved variables
   - `derive` — apply `basename-no-ext` / `dirname` / `lower` / `upper` to another variable
   - `context-inferred` — read from Phase 0 / context pass FACTS map
   - `static` — literal value
3. **Conditional skip** — if `required_if` evaluates false, skip the variable entirely
4. **Track provenance** — mark each resolved value as `detected`, `inferred`, `defaulted`, or `missing`

### Phase 3 — Confirm commands with user

Generate a confirmation table from the manifest's resolved variables. Omit variables flagged by `required_if` as inapplicable (e.g., `DB_START` when `DB_MANAGED=true`).

```
I detected the following project commands for profile <profile> (SCOPE=<scope>):

| Variable        | Value                         | Source      |
|-----------------|-------------------------------|-------------|
| BE_BUILD        | bun run build                 | detected    |
| BE_RUN          | bun run start:dev             | detected    |
| FIREBASE_EMULATOR | bun run firebase:emulator:start | detected |
| DB_MANAGED      | true                          | inferred    |
| GRAPHQL_SCHEMA_OUT | src/schema.gql             | inferred    |

Commands marked ⚠️ could not be detected. Please provide them or type "skip" to leave as TODO.

Are these correct? Edit any that need changing.
```

Wait for confirmation. Store final values.

### Phase 4 — Run scaffold script

Find the scaffold script:

```bash
find ~/.claude/plugins -name "scaffold.sh" -path "*structured-agentic-coding*" 2>/dev/null | head -1
```

If not found (manual clone), look in the cloned repo: `<repo>/structured-agentic-coding-plugin/scripts/scaffold.sh`.

Run it with all resolved values:

```bash
bash "<path-to-scaffold.sh>" \
  "<scaffold-dir>" \
  "$(pwd)" \
  "<profile>" \
  SCOPE="<scope>" \
  PREFIX="<kebab-name>" \
  PROJECT_NAME="<display-name>" \
  PROJECT_DESC="<description>" \
  <var-key>="<value>" \
  ...
```

Pass every resolved placeholder as `KEY=VALUE`. Values that could not be detected and were skipped by the user: pass `KEY="TODO: configure"`.

**After the script runs**, check its output for:
- `SKIP:` lines — files that already existed (not overwritten)
- `Files with unresolved placeholders` — files that still contain `__KEY__` tokens

If any unresolved placeholders remain, read only those specific files and replace the remaining tokens using context from Phase 0 — or ask the user for the missing values.

### Phase 5 — (Optional) Generate initial CODEMAP / stubs

If the project has no `docs/ARCHITECTURE.md`, `docs/GUIDELINES.md`, or similar, you may generate lightweight stubs referring to the templates copied into `.claude/templates/`. This is optional — many projects rely on `sac-graph` for structure instead of static codemaps.

### Phase 6 — Report

Show the script's output summary, then append:

```
### Manifest

A scaffold manifest has been written to `.claude/scaffold-manifest.json`. It
tracks the plugin version, profile, scope, and file hashes. Do not delete it —
it is used by `/upgrade-agentic-coding` and is safe to commit.

### Next Steps

1. **Review CLAUDE.md** — verify the generated documentation is accurate
2. **Customize rules** — edit `.claude/rules/*.json` to match your conventions
3. **Customize anti-patterns** — add known pitfalls to `.claude/anti-patterns.md`
4. **Try a masterplan** — say "Add [feature]" to trigger the masterplan workflow

### Quick Commands

- `/masterplan` — design and execute a multi-step feature
- `/masterplan-review` — audit a completed masterplan
- `/kill` — stop running dev servers (profile-dependent)
- `/graphql-codegen-sync` — regenerate GraphQL types (refine-nestjs-query-fe only)
- `/openapi-sync` — sync OpenAPI → frontend (angular-dotnet fullstack only)
```

## Important Rules

- **Never overwrite existing files** — the script skips them automatically. Respect its SKIP output.
- **Minimize tool calls** — the script handles bulk work. Only use Read/Edit for unresolved placeholders flagged by the script.
- **Keep agent files self-contained** — each agent file must work independently. Don't create cross-references that break if files are moved.
- **Preserve the dynamic discovery pattern** — agents discover each other via `.claude/AGENTS.md` and directory scanning, not hardcoded filenames.
- **Profile manifests are the source of truth for variables** — do not invent variables not declared in the chosen profile's `variables.json`. If you need a new variable, update the manifest.
