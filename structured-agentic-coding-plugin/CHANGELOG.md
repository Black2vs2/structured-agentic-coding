# Changelog

All notable changes to structured-agentic-coding are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.5.2] - 2026-05-27

### Fixed
- **`masterplan-executor` no longer edits source code inline.** The leaf-dispatch rule was too soft — it told the executor to use `Agent(...)` "when the procedure says to dispatch" but never explicitly forbade direct Edit/Write on code files. The model kept rationalizing "trivial" single-file FE tweaks as exceptions and bypassing the Frontend Feature Developer. Reworded as an identity rule with a closed exception list:
  - `SKILL.md`: `**Leaf dispatch only.**` → `**Orchestrate; never implement.**` Direct edits are now explicitly limited to: masterplan checkboxes, the completion report, and `.md`-only `docs` tasks. Named anti-pattern: *"reaching for Edit/Write on a code file means you skipped a dispatch — back out"*.
  - Scaffold procedure (`agents/codebase/masterplan-executor.md`): `docs`-scope row narrowed to "`.md` files only — executor edits inline, no dispatch"; added hard rule at top of per-scope handling that **code-bearing scopes (`be`, `fe`, `mixed`, `openapi-regen`, `e2e`) must always dispatch — no inline shortcuts, even for one-line tweaks**; rewrote the `docs` scope paragraph to call it out as the ONLY inline-edit scope.
- Net line delta: 0 in `SKILL.md`, −1 in scaffold procedure. Tighter language, same surface area.

### Notes
- No template, agent, or rule content changed in 4.5.2 — purely a behavioral fix to the executor's prompt. Existing scaffolds inherit the scaffold-procedure tightening on next `/upgrade-agentic-coding`; the `SKILL.md` change takes effect immediately from the plugin install.

## [4.5.1] - 2026-05-25

### Fixed
- **`upgrade.sh` now handles fragmented root templates.** Since the Phase 2 fragment refactor (commit `a314608`), `scaffold.sh` has assembled `CLAUDE.md`, `.claude/AGENTS.md`, and `.claude/settings.json` from `_core.<ext>` + `_be-section.<ext>` + `_fe-section.<ext>` fragments under `base/claude/`, `base/agents-md/`, `base/settings/`. `upgrade.sh` was never updated to match — it tried to read flat `base/CLAUDE.md` / `base/AGENTS.md` / `base/settings.json` files that don't exist, leaving those three files unreachable by upgrade and emitted as `REMOVED_UPSTREAM` false positives. Added `process_fragmented_template` that mirrors `scaffold.sh`'s `render_fragmented_template` (SCOPE-aware concat + per-profile `claude-section.md` overlay for CLAUDE.md), and rewired the three call sites.
- **`upgrade.sh` REMOVED_UPSTREAM check uses `-e` instead of `-f`.** Directory-valued sources (the fragment dirs above) now resolve correctly. Previously every fragment-tracked entry was reported as `REMOVED_UPSTREAM` even when the source dir was still present.
- **Stale manifest entries are self-healed on upgrade.** Entries with `source: null` / `category: null` left behind by pre-tracking scaffold runs (or older bugs) used to inflate `REMOVED_UPSTREAM` counts and survive forever. They're now dropped on each upgrade with a `STALE: <path> (legacy entry — dropping)` log line and a `Stale dropped: N` summary.
- **`upgrade.sh` hard-requires GNU sed.** Previously the macOS Homebrew gnubin shim was best-effort: if `gnu-sed` wasn't installed, BSD sed silently misinterpreted `sed -i "s|...|g" file` (treating the script as the backup extension) and emitted cryptic mid-run errors without aborting. The script now detects via `sed --version | grep '^GNU sed'` and exits with a clear `brew install gnu-sed` message before doing any work.

### Notes
- No template or agent content changed in 4.5.1 — purely a fix to the upgrade engine. Re-running `/upgrade-agentic-coding` from 4.5.0 (or earlier) will now correctly refresh `CLAUDE.md`, `AGENTS.md`, and `settings.json`, and clean any legacy stale entries from the manifest in a single pass.

## [4.5.0] - 2026-05-25

### Added
- **New subagent `masterplan-compliance-scanner`** — dispatched in parallel with `masterplan-griller` during architect Phase 3b. Mirrors the griller's contract (same YAML output shape, same per-round invocation) but with the opposite anti-pattern: it **specifically audits the architect's reasoning** against `.claude/rules/be-rules.json`, `.claude/rules/fe-rules.json`, and `.claude/anti-patterns.md`. Closes the gap where a rule violation pre-rationalized in the masterplan would propagate unchallenged through the dev/reviewer chain. Three dimensions: Rule Compliance, Anti-Pattern Match, Rationalization Audit (`scaffold/base/agents/codebase/masterplan-compliance-scanner.md`).
- **Rule Exception Block** in the masterplan task format — when a task deliberately deviates from a project rule, it MUST include a structured `Rule exception:` block with `Rule violated`, `Alternatives tried` (≥ 2 concrete attempts with concrete failure reasons), and `Rationale`. Free-form "ECCEZIONE ESPLICITA" prose elsewhere in the plan is no longer recognised — only the structured block. The compliance-scanner's Rationalization Audit enforces this: a missing block or handwavy alternatives is a critical finding.
- **Rules digest in architect Phase 1** — the masterplan-architect now reads `.claude/rules/{be,fe}-rules.json` (categories + names + check fields; skips `why`/`fix`) during Orient. This is the hard-constraint surface the architect designs WITHIN, so rule conflicts surface as Phase 2 clarifying questions instead of as post-hoc rationalizations.

### Changed
- **Architect Phase 3b is now parallel** — dispatches BOTH `masterplan-griller` and `masterplan-compliance-scanner` in a single turn (two Task calls), then merges findings. Loop continues if EITHER subagent returns `verdict: revise`; exits when BOTH return `pass`. Same 3-round cap.
- **Self-Grill log format** — `#### Round {N}` now contains two sub-tables (`##### Griller findings`, `##### Compliance findings`). Compliance table includes a `Rule` column citing the violated `rule_id` or anti-pattern title.
- **User-Grill question ordering** — compliance findings surface first (rule deviations are the highest-stakes user decisions), then griller findings, then architect-initiated questions. Tags distinguish source: `[from Compliance R{N} C{M}]` vs `[from Self-Grill R{N} F{M}]`.

### Notes
- **No executor changes.** Per-task rule injection in `masterplan-executor` is unchanged — the new scanner sits at architect phase as a gate before any dev dispatch, which is structurally a better moment to catch pre-rationalized violations than executor pre-flight (the masterplan would already be authoritative by then).
- **External-model substitution still works for the griller** but the compliance-scanner is not substitutable — it needs deterministic read access to `.claude/rules/*.json`, which external MCPs do not have.

## [4.4.0] - 2026-04-16

### Added
- **New profile `angular-fe`** — Angular + Nx + Playwright frontend rules, agents, and scan playbooks split out of the former monolithic `angular-dotnet` profile. Selectable standalone for split-repo setups (Angular frontend + non-.NET backend).
- **New profile `dotnet-be`** — .NET Clean Architecture + CQRS + EF Core + PostgreSQL backend rules, agents, and scan playbooks split out of the former `angular-dotnet` profile. Selectable standalone for split-repo setups (.NET backend + non-Angular frontend).
- **Composed (umbrella) profiles** — A profile may declare `"composedFrom": [...]` in its `variables.json`. The scaffold script expands the umbrella into its children (in declared order, umbrella last) and scaffolds every profile's files in the same run. Variables, context_hints, and anti-patterns from each profile are merged. The manifest records both the selected `profile` (scalar) and the resolved `profiles` array (new field).

### Changed
- **`angular-dotnet` is now an umbrella profile** composing `angular-fe` + `dotnet-be`. It carries only the fullstack-only content (`/openapi-sync` command, the openapi-sync and e2e-agent domain agents, cross-layer anti-patterns). Existing scaffolds continue to upgrade transparently — `upgrade.sh` reads the new `profiles` array when present and falls back to resolving `composedFrom` on legacy single-profile manifests.
- **Scaffold skill (`SKILL.md`)** lists 5 profiles. Profile selection still recommends `angular-dotnet` for projects with both Angular and .NET, but users may now override to scaffold either side alone.

## [4.3.2] - 2026-04-16

### Added
- **nestjs-query-be: 17 new rules** backported from sps-app-backend production usage:
  - TypeORM: BE-TYPEORM-007 (entity↔migration match), BE-TYPEORM-008 (bidirectional relations)
  - nestjs-query: BE-QUERY-006–015 (QueryService override, wrapper inputs, dtos not resolvers, owning module import, scalar resolvers, arrow function, DTO return, single input arg, CreateDTOClass, wrapper readiness)
  - Auth: BE-AUTH-006–009 (@Authorize on DTOs, PartnerAssignedGuard, @LoggedUser on mutations, requestFilterKey docs)
  - Validation: BE-VAL-006 (@Type + @ValidateNested on nested arrays)
- **nestjs-query-be: 15 new scan playbook sections** matching the new rules in auth, nestjs-query, typeorm, and validation playbooks
- **nestjs-query-be: 3 new anti-patterns** — entity without migration, ambiguous Number scalar on FilterableField, missing CreateDTOClass/UpdateDTOClass on CRUDResolver

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
