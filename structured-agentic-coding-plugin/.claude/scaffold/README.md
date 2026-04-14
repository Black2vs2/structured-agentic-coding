# Agentic Coding Scaffold

A complete agentic development infrastructure for Claude Code. Scaffolds agents, rules, commands, templates, and documentation into any monorepo project.

## What You Get

### Base (any tech stack)

| Component | What it does |
|-----------|-------------|
| **Masterplan System** | Architect → Executor → Reviewer workflow for multi-step features |
| **Graph CLI** | CLI tool (`sac-graph`) that auto-indexes the codebase and exposes structural navigation commands |
| **Doc Enforcer** | Scans for missing module documentation |
| **Research Agent** | Produces feature proposals with codebase analysis and industry research |
| **Impact Analyst** | Traces ripple effects of proposed changes across all layers |
| **Commands** | `/masterplan`, `/masterplan-review`, `/rebuild-graph`, `/kill` |
| **Templates** | ARCHITECTURE.md and GUIDELINES.md templates for new modules |
| **Anti-Patterns** | Living document of known failure modes |
| **CLAUDE.md** | Root project config with commands, conventions, agent discovery |

### Angular + .NET Profile (on top of base)

| Component | What it does |
|-----------|-------------|
| **Backend Feature Developer** | Implements .NET/C# code following Clean Architecture |
| **Backend Code Reviewer** | Reviews .NET code via 12 scan playbooks (67 rules) |
| **Backend Fixer** | Surgical fixes for backend rule violations |
| **Backend Coverage Checker** | Verifies test coverage per handler |
| **Frontend Feature Developer** | Implements Angular/TypeScript with signals, stores, PrimeNG |
| **Frontend Code Reviewer** | Reviews Angular code via 19 scan playbooks (93 rules) |
| **Frontend Fixer** | Surgical fixes for frontend rule violations |
| **Quality Test Writer** | Generates Playwright quality specs |
| **Backend Test Generator** | Generates xUnit integration tests |
| **Frontend Test Generator** | Generates Vitest unit tests for stores/services |
| **E2E Agent** | Browser-based end-to-end testing via Playwright |
| **OpenAPI Sync** | Regenerates frontend API client from backend spec |
| **93 Frontend Rules** | Angular, Signals, State Management, Forms, i18n, Design System |
| **67 Backend Rules** | Clean Architecture, EF Core, CQRS, Security, Testing |
| **31 Scan Playbooks** | Automated grep-based code review patterns |

## Installation

### Option A: Global install (recommended)

Copy the skill and scaffold to your global Claude Code config:

```bash
# Copy the init command
cp .claude/commands/structured-agentic-coding.md ~/.claude/commands/

# Copy the scaffold templates
cp -r .claude/scaffold ~/.claude/scaffold
```

Then run `/structured-agentic-coding` in any project.

### Option B: Per-project

Copy `.claude/commands/structured-agentic-coding.md` and `.claude/scaffold/` into the target project, then run `/structured-agentic-coding`.

## Usage

```
/structured-agentic-coding
```

The skill will:

1. **Ask** for your project name, profile (base/angular-dotnet), and description
2. **Detect** your project structure, build commands, test commands, formatters, database
3. **Confirm** detected commands — you can edit any that are wrong or fill in missing ones
4. **Scaffold** all agents, rules, commands, templates, and config files
5. **Generate** initial CLAUDE.md and agent manifest
6. **Report** what was created and next steps

## After Scaffolding

1. **Review `CLAUDE.md`** — Verify project info, commands, and conventions
2. **Run `sac-graph rebuild`** — Index the codebase for graph-based structural navigation
3. **Customize rules** — Edit `.claude/rules/*.json` for your conventions
4. **Customize anti-patterns** — Add known pitfalls to `.claude/anti-patterns.md`
5. **Try it** — Say "Add [feature]" to trigger your first masterplan

## How It Works

### Agent Discovery

Agents discover each other dynamically — no hardcoded filenames:

1. `.claude/AGENTS.md` is the manifest (auto-generated — run `bash .claude/scripts/regenerate-agents-md.sh` to update)
2. Orchestrator agents scan `.claude/agents/` directories to find specialists
3. Agent files are named `{prefix}-{role}.md` where prefix is your project name

### Masterplan Workflow

```
User: "Add user authentication"
  → Masterplan Architect asks clarifying questions, designs a plan
  → Plan saved to docs/masterplans/user-auth.md
  → Masterplan Executor dispatches dev agents per task
  → Code Reviewer validates each task
  → Fixer agent resolves violations (max 3 iterations)
  → Masterplan Reviewer audits the implementation
```

### Scan Playbooks

Each scan playbook contains grep patterns for detecting code violations:

```
# Example: signals.md
## FE-SIG-001: Signal-based API
Grep: @Input\(\) → in frontend/libs/**/*.ts
True positive: decorator on standalone component
False positive: decorator in test file
```

Code reviewers run these playbooks automatically during reviews.

## Customization

### Adding a new agent

1. Create `{prefix}-{role}.md` in the appropriate `.claude/agents/` directory
2. Run `bash .claude/scripts/regenerate-agents-md.sh` to update the agent manifest
3. The masterplan executor will discover it automatically

### Adding rules

Edit `.claude/rules/fe-rules.json` or `.claude/rules/be-rules.json`. Rules follow this structure:

```json
{
  "id": "FE-CUSTOM-001",
  "category": "custom",
  "severity": "warning",
  "title": "Short description",
  "description": "Detailed explanation with rationale",
  "check": "How to verify (grep pattern or manual check)"
}
```

### Adding scan playbooks

Create a new `.md` file in the appropriate `be-scans/` or `fe-scans/` directory. Follow the existing playbook format with grep patterns and true/false positive guidance.

## Directory Structure After Scaffolding

```
project-root/
├── CLAUDE.md                              # Project config for Claude Code
├── .code-graph/                           # Auto-indexed graph data (sac-graph CLI)
├── .claude/
│   ├── agents/
│   │   ├── codebase/                      # Masterplan, doc-enforcer agents
│   │   │   ├── {prefix}-masterplan-architect.md
│   │   │   ├── {prefix}-masterplan-executor.md
│   │   │   ├── {prefix}-masterplan-reviewer.md
│   │   │   └── {prefix}-doc-enforcer.md
│   │   └── domain/                        # Research, impact, test generators
│   │       ├── {prefix}-research.md
│   │       ├── {prefix}-impact-analyst.md
│   │       └── ... (profile-specific)
│   ├── commands/
│   │   ├── masterplan.md
│   │   ├── masterplan-review.md
│   │   ├── rebuild-graph.md
│   │   └── kill.md
│   ├── rules/                             # (profile-specific)
│   │   ├── fe-rules.json
│   │   └── be-rules.json
│   ├── templates/
│   │   ├── ARCHITECTURE.template.md
│   │   └── GUIDELINES.template.md
│   ├── AGENTS.md                          # Auto-generated agent manifest
│   ├── anti-patterns.md                   # Known failure modes
│   └── settings.json                      # Claude Code settings
├── frontend/                              # (if exists)
│   └── .claude/agents/
│       ├── {prefix}-frontend-feature-developer.md
│       ├── {prefix}-frontend-code-reviewer.md
│       ├── {prefix}-frontend-fixer.md
│       └── fe-scans/*.md
├── backend/                               # (if exists)
│   └── .claude/agents/
│       ├── {prefix}-backend-feature-developer.md
│       ├── {prefix}-backend-code-reviewer.md
│       ├── {prefix}-backend-fixer.md
│       └── be-scans/*.md
└── docs/
    ├── masterplans/
    │   └── executed/
    └── reports/
```

## Placeholder Reference

Templates use `__PLACEHOLDER__` tokens that get replaced during scaffolding:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `__PREFIX__` | Agent file prefix (kebab-case) | `my-app` |
| `__PROJECT_NAME__` | Display name (Title Case) | `My App` |
| `__PROJECT_DESC__` | One-line project description | `A SaaS recruitment platform` |
| `__FE_DIR__` | Frontend directory | `frontend` |
| `__BE_DIR__` | Backend directory | `backend` |
| `__FE_SERVE__` | Frontend serve command | `cd frontend && npm run dev` |
| `__FE_BUILD__` | Frontend build command | `cd frontend && npm run build` |
| `__FE_TEST__` | Frontend test command | `cd frontend && npm run test` |
| `__FE_FORMAT__` | Frontend format command | `cd frontend && npx prettier --write .` |
| `__FE_LINT__` | Frontend lint command | `cd frontend && npx nx lint` |
| `__BE_BUILD__` | Backend build command | `dotnet build backend/App.sln` |
| `__BE_TEST__` | Backend test command | `dotnet test backend/App.sln` |
| `__BE_RUN__` | Backend run command | `dotnet run --project backend/src/App.Api` |
| `__BE_FORMAT__` | Backend format command | `dotnet csharpier backend/` |
| `__DB_START__` | Database start command | `docker compose up -d` |
| `__MIGRATION__` | Migration command template | `dotnet ef migrations add ...` |
| `__BE_SLN__` | Backend solution file path | `backend/App.sln` |
| `__BE_API_PROJECT__` | Backend API project path | `backend/src/App.Api` |
| `__E2E_CMD__` | E2E test command | `cd frontend && npm run e2e` |
