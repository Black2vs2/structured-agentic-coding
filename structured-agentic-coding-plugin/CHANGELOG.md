# Changelog

All notable changes to structured-agentic-coding are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
