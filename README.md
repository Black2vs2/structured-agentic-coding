<div align="center">

# Init Agentic

**Structured agent infrastructure for Claude Code projects.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Works with Claude Code](https://img.shields.io/badge/Works_with-Claude_Code-orange)]()

[Quick Start](#quick-start) &middot; [Features](#features) &middot; [Roadmap](#roadmap) &middot; [Contributing](#contributing)

</div>

---

Install one skill. Get a full team of specialized agents — architects, developers, reviewers, testers — wired together through masterplans, coding rules, and quality gates. Your AI coding sessions go from ad-hoc conversations to structured, traceable workflows.

```
/init-agentic
```

## Why

AI coding assistants don't scale without structure. As projects grow:

- Multi-step features get lost in ad-hoc conversations — no plan, no review, no traceability.
- Generated code ignores your team's conventions, patterns, and quality expectations.
- There's no way to split work across specialized agents with clear responsibilities.
- The same mistakes repeat because agents have no institutional memory.

Init Agentic scaffolds a complete `.claude/` infrastructure into your project: agents that plan, build, review, and test — governed by explicit rules and connected through a masterplan workflow.

## Quick Start

> [!NOTE]
> Requires [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and a git repository.

**1. Clone the repo anywhere on your machine**

```bash
git clone https://github.com/Black2vs2/black2vs2-agentic-coding.git ~/any/path/you/want
```

**2. Open Claude Code in your target project and run the scaffold**

```
/init-agentic
```

Claude Code discovers skills from `.claude/` directories. As long as you run the command from within a project, the skill reads its templates from the cloned repo and scaffolds everything into your project's `.claude/` directory.

**3. Answer three questions** — project name (kebab-case), profile (`base` or `angular-dotnet`), and a one-line description.

**4. Confirm detected commands** — the skill scans your repo and presents detected build/test/serve commands. Confirm or correct them.

**5. Start building**

```
/masterplan
```

That's it. Your project now has agents, rules, scan playbooks, and documentation templates ready to use.

> [!TIP]
> The cloned repo is only needed to run `/init-agentic`. Once scaffolding is complete, all generated files live inside your project. You can safely delete the cloned repo — your project is fully self-contained.

## Features

| | Base Profile | Angular + .NET Profile |
|---|---|---|
| **Agents** | 7 — masterplan architect/executor/reviewer, codemap updater, doc enforcer, research, impact analyst | 7 + 12 stack-specific — feature devs, code reviewers, fixers, test generators, E2E, OpenAPI sync |
| **Coding Rules** | — | 160 (67 backend, 93 frontend) |
| **Scan Playbooks** | — | 31 (12 backend, 19 frontend) |
| **Commands** | `/masterplan` `/masterplan-review` `/update-codemaps` `/kill` | All base + `/openapi-sync` |
| **Documentation** | CLAUDE.md, AGENTS.md, CODEMAP stubs, anti-patterns, templates | Same + stack-specific anti-patterns |

### Commands

| Command | Purpose |
|---|---|
| `/masterplan` | Design and execute a multi-step feature with coordinated agents |
| `/masterplan-review` | Audit a completed masterplan for implementation completeness |
| `/update-codemaps` | Regenerate structural documentation from the live codebase |
| `/kill` | Stop running dev servers |
| `/openapi-sync` | Regenerate frontend API client from backend OpenAPI spec *(angular-dotnet only)* |

### Supported Stacks

**Base** — framework-agnostic. Masterplan workflow, codemap system, doc enforcement, research and impact analysis. Works with any language or framework.

**Angular + .NET** — fully configured for Angular 21+ (standalone components, Signals, Nx), .NET 8+ (Clean Architecture, CQRS/MediatR), PostgreSQL/EF Core, OpenAPI 3.x, Jest/Vitest + xUnit/NUnit + Playwright.

<details>
<summary><strong>Project structure</strong></summary>

```
.claude/scaffold/
├── base/                              # Always applied
│   ├── agents/codebase/               # Masterplan, codemap, doc-enforcer agents
│   ├── agents/domain/                 # Research, impact analyst agents
│   ├── commands/                      # Slash commands
│   ├── templates/                     # ARCHITECTURE + GUIDELINES templates
│   ├── CLAUDE.md                      # Root project documentation template
│   ├── AGENTS.md                      # Agent manifest template
│   ├── anti-patterns.md               # Known failure modes
│   └── settings.json                  # Claude Code harness config
└── profiles/angular-dotnet/           # Added when profile = angular-dotnet
    ├── agents/backend/                # BE dev, reviewer, fixer, coverage checker
    ├── agents/frontend/               # FE dev, reviewer, fixer, test writer
    ├── agents/domain/                 # Test generators, E2E agent, OpenAPI sync
    ├── scans/be-scans/                # 12 backend code review playbooks
    ├── scans/fe-scans/                # 19 frontend code review playbooks
    ├── rules/                         # be-rules.json (67), fe-rules.json (93)
    └── anti-patterns-profile.md       # Stack-specific anti-patterns
```

</details>

## Roadmap

### RALF Loop — Non-Technical User Requests

- [ ] **RALF (Request → Assess → Loop → Finalize) workflow** — a structured intake loop that translates non-technical requests (e.g. "I need an assessment module") into actionable masterplans. The RALF agent interviews the user in plain language, extracts requirements, validates feasibility against the current codebase, and iterates until the request is unambiguous enough to feed into the masterplan architect. Designed for product owners, stakeholders, and domain experts who don't write code.

### Deferred Documentation Updates

- [ ] **Scheduled off-hours maintenance** — automatically refresh CODEMAPs, ARCHITECTURE.md, GUIDELINES.md, AGENTS.md, and anti-patterns at a configured time (e.g. midnight) when no one is working and no context window is in use. Runs as a scheduled Claude Code remote agent triggered via cron.

### Worktree-Based Parallel Development

- [ ] **Git worktree execution mode** — run masterplan phases in isolated git worktrees so that multiple features can be developed in parallel without branch conflicts. Each feature gets its own worktree, its own agent session, and its own commit history. When complete, the worktree is merged or a PR is opened automatically.

### Remote Container Agents

- [ ] **Docker-based remote execution** — spin up agents inside Docker containers or remote VMs with full permissions. Agents operate in their own sandboxed environment, run the full build/test cycle, and produce ready-made pull requests with passing CI. This enables:
  - **Full isolation** — install dependencies, run migrations, start services, execute E2E tests without affecting the developer's machine.
  - **Parallel agent fleet** — multiple containers work simultaneously on different features or masterplan phases.
  - **Ready-to-review PRs** — agents push branches and open PRs with build status, test results, and change summaries.
  - **Team scaling** — one developer orchestrates a fleet of container agents, multiplying throughput.

<details>
<summary><strong>Additional planned features</strong></summary>

- [ ] **Profile auto-detection** — automatically select the profile based on detected tech stack
- [ ] **Incremental scaffolding** — update scaffolded files when templates change (version upgrade path)
- [ ] **Custom profile composition** — mix frontend/backend profiles independently
- [ ] **Agent performance metrics** — track review accuracy, fix success rate, and surface insights
- [ ] **CI/CD integration** — pipeline steps that invoke scan playbooks automatically

</details>

## Contributing

Contributions are welcome — new profiles, agents, scan playbooks, rules, and bug fixes.

**Getting started:**

1. Fork and clone the repository.
2. Create a feature branch: `git checkout -b feat/your-feature`.
3. Make your changes following the guidelines below.
4. Test by running `/init-agentic` in a sample project.
5. Submit a pull request.

<details>
<summary><strong>What to contribute</strong></summary>

- **New profiles** — support for other stacks. Create a directory under `.claude/scaffold/profiles/` following the `angular-dotnet` structure.
- **New agents** — specialized agents for specific workflows.
- **New scan playbooks** — code review checklists for specific domains.
- **Rule improvements** — refine or add rules in `rules/*.json` (each needs an ID, description, category, severity).
- **Bug fixes** — placeholder replacement issues, template errors, agent behavior problems.
- **Anti-patterns** — document failure modes in `.claude/scaffold/base/anti-patterns.md`.

</details>

<details>
<summary><strong>Guidelines</strong></summary>

- **Templates must be self-contained.** Each agent file works independently. Agents discover each other through `.claude/AGENTS.md` and directory scanning.
- **Use `__PLACEHOLDER__` tokens** for values that vary per project.
- **Never overwrite user files.** The scaffold skips existing files.
- **Follow conventional commits:** `feat:`, `fix:`, `docs:`, `refactor:`.
- **Keep rules actionable.** Each rule must be specific enough for an agent to verify programmatically.

</details>

<details>
<summary><strong>Adding a new profile</strong></summary>

1. Create `.claude/scaffold/profiles/<profile-name>/`.
2. Add `agents/`, `scans/`, `rules/` subdirectories as needed.
3. Add an `anti-patterns-profile.md` for stack-specific failure modes.
4. Update the profile list in `.claude/commands/init-agentic.md` Phase 1.
5. Add detection logic for the new stack in Phase 2 of the init command.
6. Document the profile in this README under [Supported Stacks](#supported-stacks).

</details>

## Author

Built by **Luca Sartori** — software engineer with years of experience across full-stack development, now focused on AI-augmented workflows. This project comes from hands-on work with agentic coding tools and a practical understanding of how to design agent systems that are token-efficient: minimal context consumption, deferred documentation, scoped agent prompts, and structured workflows that avoid wasting the context window on noise.

## License

MIT
