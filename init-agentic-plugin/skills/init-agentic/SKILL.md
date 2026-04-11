---
name: init-agentic
description: Scaffold a complete agent-driven development infrastructure into the current project — agents, rules, scan playbooks, masterplan workflows, and documentation templates.
---

# Init Agentic — Project Scaffolding

Scaffold a complete agentic coding infrastructure into the current project. This creates the `.claude/` directory with agents, rules, commands, templates, and a root `CLAUDE.md` — everything needed for structured, agent-driven development.

## Profiles

- **base** — Framework-agnostic core: masterplan system, codemap updater, doc enforcer, research/impact agents, templates, commands. Works with any tech stack.
- **angular-dotnet** — Everything in base, plus: Angular + .NET specialized agents (feature developers, code reviewers, fixers, test generators, E2E agent), 93 frontend rules, 67 backend rules, 31 scan playbooks.

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

**Step 1: Ask the user these questions (all at once):**

1. **Project name** — Used as the agent file prefix and display name.
   - Example: "recruit-app" → agents named `recruit-app-masterplan-architect.md`, display name "Recruit App"
   - Must be lowercase kebab-case (letters, numbers, hyphens)

2. **Profile** — Which scaffolding profile?
   - `base` — generic framework, no tech-stack specific agents/rules
   - `angular-dotnet` — Angular + Nx + .NET Clean Architecture + PostgreSQL

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

Now read templates from `.claude/scaffold/` and write them to the project, replacing all `__PLACEHOLDER__` tokens.

**Placeholder reference:**

| Placeholder          | Source                    | Example                                           |
|----------------------|---------------------------|----------------------------------------------------|
| `__PREFIX__`         | Project name (kebab-case) | `recruit-app`                                      |
| `__PROJECT_NAME__`   | Project name (Title Case) | `Recruit App`                                      |
| `__PROJECT_DESC__`   | User's description        | `A SaaS platform for recruitment`                  |
| `__FE_DIR__`         | Detected frontend dir     | `frontend`                                         |
| `__BE_DIR__`         | Detected backend dir      | `backend`                                          |
| `__FE_SERVE__`       | Confirmed command         | `cd frontend && npx nx serve recruitment`          |
| `__FE_BUILD__`       | Confirmed command         | `cd frontend && npm run build`                     |
| `__FE_TEST__`        | Confirmed command         | `cd frontend && npm run test`                      |
| `__FE_FORMAT__`      | Confirmed command         | `cd frontend && npx prettier --write .`            |
| `__FE_LINT__`        | Confirmed command         | `cd frontend && npx nx lint`                       |
| `__BE_BUILD__`       | Confirmed command         | `dotnet build backend/MyApp.sln`                   |
| `__BE_TEST__`        | Confirmed command         | `dotnet test backend/MyApp.sln`                    |
| `__BE_RUN__`         | Confirmed command         | `dotnet run --project backend/src/MyApp.Api`       |
| `__BE_FORMAT__`      | Confirmed command         | `dotnet csharpier backend/`                        |
| `__DB_START__`       | Confirmed command         | `docker compose -f docker/docker-compose.yml up -d`|
| `__MIGRATION__`      | Confirmed command         | `dotnet ef migrations add ...`                     |
| `__BE_SLN__`         | Detected .sln path        | `backend/MyApp.sln`                                |
| `__BE_API_PROJECT__` | Detected API project path | `backend/src/MyApp.Api`                            |
| `__E2E_CMD__`        | Confirmed command         | `cd frontend && npm run e2e`                       |
| `__BE_NAMESPACE__`   | .NET root namespace       | `MyApp` (used in scan playbook paths)              |

**Step 4a — Scaffold base files:**

For each file in `.claude/scaffold/base/`:
1. Read the template file
2. Replace all `__PLACEHOLDER__` tokens with actual values
3. Write to the corresponding location in the project:
   - `base/agents/codebase/*.md` → `.claude/agents/codebase/__PREFIX__-*.md`
   - `base/agents/domain/*.md` → `.claude/agents/domain/__PREFIX__-*.md`
   - `base/commands/*.md` → `.claude/commands/*.md`
   - `base/templates/*` → `.claude/templates/*`
   - `base/CLAUDE.md` → `CLAUDE.md` (project root)
   - `base/AGENTS.md` → `.claude/AGENTS.md`
   - `base/anti-patterns.md` → `.claude/anti-patterns.md`
   - `base/settings.json` → `.claude/settings.json`

Also create these directories:
```bash
mkdir -p docs/masterplans/executed docs/reports
```

**Step 4b — Scaffold profile files (if angular-dotnet):**

For each file in `.claude/scaffold/profiles/angular-dotnet/`:
1. Read the template file
2. Replace all `__PLACEHOLDER__` tokens
3. Write to the corresponding location:
   - `agents/backend/*.md` → `__BE_DIR__/.claude/agents/__PREFIX__-*.md`
   - `agents/frontend/*.md` → `__FE_DIR__/.claude/agents/__PREFIX__-*.md`
   - `agents/domain/*.md` → `.claude/agents/domain/__PREFIX__-*.md`
   - `scans/be-scans/*.md` → `__BE_DIR__/.claude/agents/be-scans/*.md`
   - `scans/fe-scans/*.md` → `__FE_DIR__/.claude/agents/fe-scans/*.md`
   - `rules/*.json` → `.claude/rules/*.json`
   - `anti-patterns-profile.md` → append to `.claude/anti-patterns.md`

Also create the OpenAPI sync command if both frontend and backend are detected:
- Read `.claude/scaffold/profiles/angular-dotnet/commands/openapi-sync.md`
- Replace placeholders, write to `.claude/commands/openapi-sync.md`

Create subdirectory structures:
```bash
mkdir -p __BE_DIR__/.claude/agents/be-scans
mkdir -p __FE_DIR__/.claude/agents/fe-scans
```

### Phase 5 — Generate Initial CODEMAP

After scaffolding, generate a minimal `CODEMAP.md` at the project root:

1. Scan the project structure (`ls` the root, key directories)
2. Write a CODEMAP.md with:
   - **Architecture** table (tech stack detected)
   - **Project Structure** tree (top-level directories with annotations)
   - **Commands** section (from confirmed commands)
   - Leave detailed sections (entities, patterns, API surface) for the codemap updater to fill

Also create placeholder frontend/backend CODEMAPs if those directories exist:
- `__FE_DIR__/CODEMAP.md` — stub with section headers
- `__BE_DIR__/CODEMAP.md` — stub with section headers

### Phase 6 — Report

Output a summary of what was created:

```
## ✅ Agentic Setup Complete

**Project:** __PROJECT_NAME__
**Profile:** base | angular-dotnet
**Agent prefix:** __PREFIX__

### Files Created

| Category        | Count | Location                              |
|-----------------|-------|---------------------------------------|
| Agents          | N     | .claude/agents/, fe/.claude/, be/.claude/ |
| Commands        | N     | .claude/commands/                     |
| Rules           | N     | .claude/rules/                        |
| Scan Playbooks  | N     | fe/.claude/agents/fe-scans/, be/.claude/agents/be-scans/ |
| Templates       | 2     | .claude/templates/                    |
| Config          | 2     | .claude/settings.json, .claude/anti-patterns.md |
| Documentation   | 3+    | CLAUDE.md, CODEMAP.md, .claude/AGENTS.md |

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

- **Never overwrite existing files** — If a file already exists at the target path, SKIP it and note in the report. The user's existing work takes priority.
- **Create directories as needed** — Use `mkdir -p` before writing files.
- **Validate placeholder replacement** — After writing each file, verify no `__PLACEHOLDER__` tokens remain. If any do, the detection missed something — use a sensible default or mark as `TODO: configure`.
- **Keep agent files self-contained** — Each agent file must work independently. Don't create cross-references that break if files are moved.
- **Preserve the dynamic discovery pattern** — Agents discover each other via `.claude/AGENTS.md` and directory scanning, not hardcoded filenames.
