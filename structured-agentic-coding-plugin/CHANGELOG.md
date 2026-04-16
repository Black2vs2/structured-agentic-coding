# Changelog

All notable changes to structured-agentic-coding are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.3.2] - 2026-04-16

### Added
- **nestjs-query-be: 17 new rules** backported from sps-app-backend production usage:
  - TypeORM: BE-TYPEORM-007 (entity↔migration match), BE-TYPEORM-008 (bidirectional relations)
  - nestjs-query: BE-QUERY-006–015 (QueryService override, wrapper inputs, dtos not resolvers, owning module import, scalar resolvers, arrow function, DTO return, single input arg, CreateDTOClass, wrapper readiness)
  - Auth: BE-AUTH-006–009 (@Authorize on DTOs, PartnerAssignedGuard, @LoggedUser on mutations, requestFilterKey docs)
  - Validation: BE-VAL-006 (@Type + @ValidateNested on nested arrays)
- **nestjs-query-be: 15 new scan playbook sections** matching the new rules in auth, nestjs-query, typeorm, and validation playbooks
- **nestjs-query-be: 3 new anti-patterns** — entity without migration, ambiguous Number scalar on FilterableField, missing CreateDTOClass/UpdateDTOClass on CRUDResolver

### Added
- **New profile `angular-fe`** — Angular + Nx + Playwright frontend rules, agents, and scan playbooks split out of the former monolithic `angular-dotnet` profile. Selectable standalone for split-repo setups (Angular frontend + non-.NET backend).
- **New profile `dotnet-be`** — .NET Clean Architecture + CQRS + EF Core + PostgreSQL backend rules, agents, and scan playbooks split out of the former `angular-dotnet` profile. Selectable standalone for split-repo setups (.NET backend + non-Angular frontend).
- **Composed (umbrella) profiles** — A profile may declare `"composedFrom": [...]` in its `variables.json`. The scaffold script expands the umbrella into its children (in declared order, umbrella last) and scaffolds every profile's files in the same run. Variables, context_hints, and anti-patterns from each profile are merged. The manifest records both the selected `profile` (scalar) and the resolved `profiles` array (new field).

### Changed
- **`angular-dotnet` is now an umbrella profile** composing `angular-fe` + `dotnet-be`. It carries only the fullstack-only content (`/openapi-sync` command, the openapi-sync and e2e-agent domain agents, cross-layer anti-patterns). Existing scaffolds continue to upgrade transparently — `upgrade.sh` reads the new `profiles` array when present and falls back to resolving `composedFrom` on legacy single-profile manifests.
- **Scaffold skill (`SKILL.md`)** lists 5 profiles. Profile selection still recommends `angular-dotnet` for projects with both Angular and .NET, but users may now override to scaffold either side alone.

## [4.3.1] - 2026-04-15

### Fixed
- **`sac-graph` CLI now reachable on PATH** — added `bin/sac-graph` wrapper. Claude Code auto-adds `<plugin>/bin` to PATH, but the previous layout had no `bin/` directory so the CLI (installed by `install-graph-server.sh` into `graph-server/.venv/bin/`) was never callable from scaffolded projects or the `/rebuild-graph` slash command. The wrapper auto-invokes `install-graph-server.sh` on first run if the venv is missing.

## [4.3.0] - 2026-04-15

### Added
- **New profile `nestjs-query-be`** — NestJS 11 + TypeORM + `@ptc-org/nestjs-query-*` + Firebase Auth + pg-boss + Jest + Bun. Backend-only (for split-repo setups). 5 agents, 42 rules, 10 scan playbooks, anti-patterns
- **New profile `refine-nestjs-query-fe`** — React 19 + Vite 7 + Refine.dev 5 + `@refinedev/nestjs-query` + shadcn/ui + Tailwind 4 + Firebase Auth + Zod v4 + Bun. Frontend-only. 5 agents + `graphql-codegen-sync` domain agent, 44 rules, 10 scan playbooks, anti-patterns
- **New slash command `/graphql-codegen-sync`** (refine-nestjs-query-fe profile) — wraps the existing `bun run codegen` pipeline with optional schema-source override
- **SCOPE flag** in scaffold.sh — `SCOPE=fe|be|fullstack` (default `fullstack` for retro-compat). Single-stack profiles use `be` / `fe` scope to cleanly scaffold split-repo projects
- **Per-profile `variables.json` manifest** — each profile declares its placeholders, detection strategies, scope rules, and conditional requirements. See `docs/variables-schema.md`
- **Context-first detection** in the skill — reads README.md, CLAUDE.md, docs/*.md BEFORE systematic globs so declared facts ("Bun required", "Zod v4") drive variable defaults
- **Always-active profile-migration detection** in `/upgrade-agentic-coding` — re-scans on every upgrade and offers migration if a different profile matches better (~5s overhead)
- **upgrade.sh `--migrate-profile <new>` flag** — carries over compatible placeholders and re-runs scaffold.sh with the new profile; scaffold.sh's skip-if-exists preserves user modifications
- **Profile CLAUDE.md overlay mechanism** — `profiles/<profile>/claude-section.md` is appended to the generated CLAUDE.md after the base fragments, letting profile-specific commands (database, migrations, emulator) live with the profile
- **Smoke test harness** — `scripts/smoke-test.sh` with fixture scaffolds and baseline diffs. Four scenarios: base-fullstack, angular-dotnet-fullstack, nestjs-query-be, refine-nestjs-query-fe

### Changed
- **Base CLAUDE.md template fragmented** into `base/claude/{_core, _be-section, _fe-section}.md`. scaffold.sh concatenates the fragments per SCOPE. `AGENTS.md` and `settings.json` use the same pattern
- **Base `_be-section.md` Backend commands** — removed `DB_START` and `MIGRATION` placeholders (those are stack-specific). Profiles re-add their specific commands via their own `claude-section.md` overlay
- **angular-dotnet migrated to manifest system** — all variables (BE_SLN, BE_NAMESPACE, BE_API_PROJECT, etc.) now declared in `profiles/angular-dotnet/variables.json` instead of hardcoded in the skill
- **scaffold.sh generic profile handler** — replaced the angular-dotnet-specific block with a generic loop that works for any profile with a `profiles/<name>/` scaffold directory
- **Manifest now records `scope`** alongside profile, placeholders, file hashes — used by the upgrade skill's profile-migration detection
- **README** — features table shows all 4 profiles with scope, agent/rule/scan counts; added profile-selection decision tree

### Fixed
- **macOS compatibility documented** — scaffold.sh requires Bash 4+ and GNU sed. README now documents `brew install bash gnu-sed` and PATH setup for macOS users (Linux and CI environments work out of the box)

## [4.2.0] - 2026-04-14

### Fixed
- Settings.json and hooks.json updated to new matcher format

## [4.1.0] - 2026-04-14

### Added
- Masterplan skills: `/masterplan`, `/masterplan-architect`, `/masterplan-executor`, `/masterplan-review`
- Orchestrator routes subcommands: architect/design/plan, execute/run, review/audit, resume
- Architect runs in main conversation context (interactive Q&A)
- Executor and reviewer spawn as agents (automated, long-running)
- Fallback architect procedure when project not scaffolded
- CLAUDE.md template now documents masterplan slash commands

### Fixed
- Windows CRLF handling in upgrade script (jq output, template rendering)
- Plugin discovery uses `sort -V | tail -1` instead of `head -1` for version ordering
- Upgrade skill documents all required placeholders for angular-dotnet profile

## [4.0.0] - 2026-04-13

### Changed
- Breaking: MCP graph tools replaced with CLI (`sac-graph`) — agents updated

## [3.2.0] - 2026-04-12

## [3.1.0] - 2026-04-12

## [3.0.0] - 2026-04-12

## [2.0.0] - 2026-04-12

## [1.0.0] - 2026-04-12

### Added
- Initial release
- Base profile: 7 agents, 3 commands, 2 templates, anti-patterns document
- Angular-dotnet profile: 12 additional agents, 160 rules (67 BE, 93 FE), 31 scan playbooks
- Scaffold script with bulk file copying and placeholder replacement
- Masterplan workflow system (architect → executor → reviewer)
- Codemap updater agent and `/update-codemaps` command
