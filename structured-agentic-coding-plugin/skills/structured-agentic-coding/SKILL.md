---
name: structured-agentic-coding
description: Scaffold a complete agent-driven development infrastructure into the current project — agents, rules, scan playbooks, masterplan workflows, and documentation templates.
---

# Structured Agentic Coding — Project Scaffolding

Scaffold a complete agentic coding infrastructure into the current project. This creates the `.claude/` directory with agents, rules, commands, templates, and a root `CLAUDE.md` — everything needed for structured, agent-driven development.

## Profiles

- **base** — Framework-agnostic core: masterplan system, codemap updater, doc enforcer, research/impact agents, templates, commands. Works with any tech stack. **Use this for any project that does NOT match a specialized profile exactly.**
- **angular-dotnet** — Everything in base, plus: Angular + .NET specialized agents (feature developers, code reviewers, fixers, test generators, E2E agent), 93 frontend rules, 67 backend rules, 31 scan playbooks. **Only use this when the project uses BOTH Angular on the frontend AND .NET (C#) on the backend.** If the project uses Angular with a non-.NET backend (e.g. Node.js, NestJS, Express, Go, Python), use `base` instead.

## Scaffold Source

Templates live in `.claude/scaffold/` relative to wherever this skill is installed:

```
.claude/scaffold/
├── base/                          # Always scaffolded
│   ├── agents/codebase/           # Masterplan, codemap, doc-enforcer
│   ├── agents/domain/             # Research, impact analyst
│   ├── commands/                  # masterplan, update-codemaps, kill
│   ├── templates/                 # ARCHITECTURE + GUIDELINES templates
│   ├── CLAUDE.md                  # Root CLAUDE.md template
│   ├── AGENTS.md                  # Agent manifest template
│   ├── anti-patterns.md           # Anti-patterns starter
│   └── settings.json              # Claude Code settings
└── profiles/angular-dotnet/       # Added when profile = angular-dotnet
    ├── agents/backend/            # BE dev, reviewer, fixer, coverage
    ├── agents/frontend/           # FE dev, reviewer, fixer, test writer
    ├── agents/domain/             # BE/FE test generators, E2E agent
    ├── scans/be-scans/            # 12 backend scan playbooks
    ├── scans/fe-scans/            # 19 frontend scan playbooks
    ├── rules/                     # fe-rules.json, be-rules.json
    └── anti-patterns-profile.md   # Stack-specific anti-patterns
```

## Procedure

### Phase 1 — Gather Information (interactive)

**Step 0: Quick-scan the project to determine the correct profile BEFORE asking the user.**

Run these checks silently:
- `Glob("**/*.csproj")` and `Glob("**/*.sln")` — if .NET files are found, the backend is .NET.
- `Glob("**/package.json")` — read dependencies to detect Angular (`@angular/core`), and Node.js backends (`@nestjs/core`, `express`, `fastify`, `hapi`, etc.).

**Profile selection logic:**
- If BOTH `@angular/core` AND `.csproj`/`.sln` files are detected → recommend `angular-dotnet`
- In ALL other cases → recommend `base`
- Angular + Node.js (NestJS, Express, etc.) = `base`, NOT `angular-dotnet`
- React/Vue/Svelte + anything = `base`
- No frontend framework detected = `base`

**Step 1: Ask the user these questions (all at once), including your profile recommendation:**

1. **Project name** — Used as the agent file prefix and display name.
   - Example: "recruit-app" → agents named `recruit-app-masterplan-architect.md`, display name "Recruit App"
   - Must be lowercase kebab-case (letters, numbers, hyphens)

2. **Profile** — Which scaffolding profile? Present your recommendation based on the scan, but let the user override.
   - `base` — generic framework, no tech-stack specific agents/rules
   - `angular-dotnet` — Angular + Nx + .NET Clean Architecture + PostgreSQL (only when BOTH Angular AND .NET are detected)

3. **Project description** — One sentence describing what the project does.
   - Example: "A SaaS platform for managing recruitment assessments and code challenges"

Wait for the user's answers before proceeding.

### Phase 2 — Auto-Detect Project Structure

Scan the current working directory to detect commands and structure. Be methodical:

**Frontend detection:**
```
Glob("**/package.json") — find all package.json files
```
- Read the root or frontend package.json `scripts` section
- Look for: `serve`/`start`/`dev` (serve cmd), `build`, `test`, `lint`, `format`/`prettier`
- Detect framework from `dependencies`: `@angular/core`, `react`, `next`, `vue`
- Detect if Nx monorepo: check for `nx.json` or `@nx/` deps
- Detect test runner: `vitest`, `jest`, `karma`
- Detect formatter: `prettier` in devDeps or scripts

**Backend detection:**
```
Glob("**/*.sln") — find solution files
Glob("**/*.csproj") — find project files
```
- Find the main API/Web project (look for `Program.cs` or `Startup.cs`)
- Construct: `dotnet build <sln-path>`, `dotnet test <sln-path>`, `dotnet run --project <api-project-path>`
- Detect formatter: check for `csharpier` in tool manifest (`.config/dotnet-tools.json`)
- Detect ORM: check for `Microsoft.EntityFrameworkCore` in csproj files
- Detect root namespace: look at the `<RootNamespace>` in csproj files, or derive from the `.sln` filename (e.g., `MyApp.sln` → `MyApp`). This becomes `__BE_NAMESPACE__`

**Database detection:**
```
Glob("**/docker-compose*.yml") — find Docker Compose files
```
- Read compose files to identify database service
- Construct start command: `docker compose -f <path> up -d`

**Migration detection:**
- If EF Core detected, find migrations project path
- Construct: `dotnet ef migrations add <Name> --project <migrations-project> --startup-project <api-project>`

**E2E detection:**
```
Glob("**/playwright.config.*") — Playwright
Glob("**/cypress.config.*") — Cypress
```

### Phase 3 — Confirm Commands with User

Present the detected commands in a table and ask the user to confirm or correct:

```
I detected the following project commands:

| Command           | Detected Value                                    |
|-------------------|---------------------------------------------------|
| Frontend serve    | cd frontend && npx nx serve app-name              |
| Frontend build    | cd frontend && npm run build                      |
| Frontend test     | cd frontend && npm run test                       |
| Frontend format   | cd frontend && npx prettier --write .             |
| Frontend lint     | cd frontend && npx nx lint                        |
| Backend build     | dotnet build backend/MyApp.sln                    |
| Backend test      | dotnet test backend/MyApp.sln                     |
| Backend run       | dotnet run --project backend/src/MyApp.Api        |
| Backend format    | dotnet csharpier backend/                         |
| Database start    | docker compose -f docker/docker-compose.yml up -d |
| Migrations        | dotnet ef migrations add <Name> --project ...     |
| E2E tests         | cd frontend && npx playwright test                |
| BE namespace      | MyApp (from .sln name)                            |

Commands marked with ⚠️ could not be detected. Please provide them or type "skip" to leave as placeholder.

Are these correct? Edit any that need changing.
```

Wait for confirmation. Store the final values.

### Phase 4 — Scaffold Files

**Use the scaffold script** to bulk-copy and replace placeholders in a single command. Do NOT read/write template files individually — that wastes tokens and time.

The script is at `scripts/scaffold.sh` relative to wherever this skill is installed. Find it:

```bash
# The plugin cache location — look for the scaffold script
find ~/.claude/plugins -name "scaffold.sh" -path "*/structured-agentic-coding*" 2>/dev/null | head -1
```

If not found (manual clone), look in the cloned repo: `<repo>/structured-agentic-coding-plugin/scripts/scaffold.sh`.

**Run the script** with all placeholder values collected from Phases 1–3. Pass every confirmed value as a `KEY=VALUE` argument. The script handles all file copying, directory creation, path mapping, and placeholder replacement in bulk.

```bash
bash "<path-to-scaffold.sh>" \
  "<path-to-scaffold-dir>" \
  "$(pwd)" \
  "<profile>" \
  PREFIX="<kebab-name>" \
  PROJECT_NAME="<Title Case Name>" \
  PROJECT_DESC="<description>" \
  FE_DIR="<frontend-dir>" \
  BE_DIR="<backend-dir>" \
  FE_SERVE="<cmd>" \
  FE_BUILD="<cmd>" \
  FE_TEST="<cmd>" \
  FE_FORMAT="<cmd>" \
  FE_LINT="<cmd>" \
  BE_BUILD="<cmd>" \
  BE_TEST="<cmd>" \
  BE_RUN="<cmd>" \
  BE_FORMAT="<cmd>" \
  DB_START="<cmd>" \
  MIGRATION="<cmd>" \
  BE_SLN="<path>" \
  BE_API_PROJECT="<path>" \
  E2E_CMD="<cmd>" \
  BE_NAMESPACE="<namespace>"
```

The `<path-to-scaffold-dir>` is the `.claude/scaffold/` directory next to the script (same plugin/repo root).

**For commands that were not detected or skipped:** pass `TODO: configure` as the value. The script will leave those as markers for the user to fill in later.

**After the script runs**, check its output for:
- `SKIP:` lines — files that already existed (not overwritten)
- `Files with unresolved placeholders` — files that need manual attention

**If any unresolved placeholders remain**, read only those specific files and replace the remaining tokens using context from the project scan. This is the only time you should use Read/Edit on scaffold output — and only for the files the script flagged.

### Phase 5 — Generate Initial CODEMAP

After scaffolding, generate a minimal `CODEMAP.md` at the project root. This is the one file that requires AI generation (not template copying):

1. Scan the project structure (`ls` the root, key directories)
2. Write a CODEMAP.md with:
   - **Architecture** table (tech stack detected)
   - **Project Structure** tree (top-level directories with annotations)
   - **Commands** section (from confirmed commands)
   - Leave detailed sections (entities, patterns, API surface) for the codemap updater to fill

Also create placeholder frontend/backend CODEMAPs if those directories exist:
- `<FE_DIR>/CODEMAP.md` — stub with section headers
- `<BE_DIR>/CODEMAP.md` — stub with section headers

### Phase 6 — Report

Show the script's output summary to the user, then append:

```
### Manifest

A scaffold manifest has been written to `.claude/scaffold-manifest.json`. This file tracks which plugin version generated your files and enables future upgrades via `/upgrade-agentic-coding`. Do not delete it. It is safe to commit.

### Next Steps

1. **Review CLAUDE.md** — Verify the generated project documentation is accurate
2. **Run `/update-codemaps`** — Generate detailed CODEMAPs from your codebase
3. **Customize rules** — Edit `.claude/rules/*.json` to match your conventions
4. **Customize anti-patterns** — Add known pitfalls to `.claude/anti-patterns.md`
5. **Try a masterplan** — Say "Add [feature]" to trigger the masterplan workflow

### Quick Commands

- `/masterplan` — Design and execute a multi-step feature
- `/masterplan-review` — Review a completed masterplan
- `/update-codemaps` — Refresh structural documentation
- `/kill` — Stop running dev servers
```

## Important Rules

- **Never overwrite existing files** — The script skips them automatically. Respect its SKIP output.
- **Minimize tool calls** — The script handles bulk work. Only use Read/Edit for unresolved placeholders flagged by the script and for CODEMAP generation.
- **Keep agent files self-contained** — Each agent file must work independently. Don't create cross-references that break if files are moved.
- **Preserve the dynamic discovery pattern** — Agents discover each other via `.claude/AGENTS.md` and directory scanning, not hardcoded filenames.
