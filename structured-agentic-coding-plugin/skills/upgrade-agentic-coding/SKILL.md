---
name: upgrade-agentic-coding
description: Upgrade an existing structured-agentic-coding scaffold to the latest plugin version — selective category updates with modification detection.
---

# Upgrade Agentic Coding

Upgrade a previously scaffolded project to the current plugin version. Compares file hashes to detect user modifications, allows selective category upgrades, and preserves edited files.

## Prerequisites

- Project must have `.claude/scaffold-manifest.json` (created by `/structured-agentic-coding`)
- `jq` must be installed (the upgrade script requires it for manifest parsing)

## Procedure

### Step 1 — Read Manifest and Detect Versions

Read the scaffold manifest and determine the version delta:

```bash
cat .claude/scaffold-manifest.json
```

Extract the `version` field from the manifest. Then find the plugin's current version:

```bash
# Find the plugin root (use sort -V to pick the highest version, not just the first match)
PLUGIN_ROOT=$(find ~/.claude/plugins -name "plugin.json" -path "*/structured-agentic-coding*" -exec dirname {} \; 2>/dev/null | sort -V | tail -1)
PLUGIN_ROOT=$(dirname "$PLUGIN_ROOT")
cat "$PLUGIN_ROOT/.claude-plugin/plugin.json"
```

If the manifest does not exist, tell the user:
> "No scaffold manifest found. Run `/structured-agentic-coding` to scaffold your project first."
Stop here.

If the versions match, tell the user:
> "Your project is already up to date (v{version})."
Stop here.

### Step 2 — Show Status Report

Read the CHANGELOG.md from the plugin directory and extract the sections between the manifest version and the current version:

```bash
cat "$PLUGIN_ROOT/CHANGELOG.md"
```

Present the status:

```
Upgrade available for: {project name from manifest placeholders.PREFIX}
  Profile: {manifest profile}
  Current version: {manifest version}
  Available version: {plugin version}

Changes since v{manifest version}:
  {relevant CHANGELOG sections}
```

### Step 3 — Category Selection

Present the categories with defaults. Read the manifest's files to count how many files are in each category:

```
Which categories do you want to update?
  [x] Core agents — {N} files (masterplan architect/executor/reviewer, codemap-updater, etc.)
  [x] Profile agents — {N} files (BE/FE feature devs, reviewers, fixers, test generators)
  [x] Commands — {N} files (masterplan.md, update-codemaps.md, etc.)
  [x] Templates — {N} files (CLAUDE.md, AGENTS.md, ARCHITECTURE.template.md)
  [ ] Rules & scan playbooks — {N} files (be-rules.json, fe-rules.json, scan playbooks)
  [ ] Config — {N} files (settings.json, anti-patterns.md)
```

Default selected: `agents-core`, `agents-profile`, `commands`, `templates`.
Default unselected: `rules-scans`, `config`.

If the profile is `base`, omit the "Profile agents" row and `rules-scans` (those only exist for angular-dotnet).

Wait for the user to confirm or adjust their selection.

### Step 4 — Modification Detection and Conflict Decision

For all files in the selected categories, compare the current file hash on disk against the manifest hash:

```bash
# For each file entry in the manifest matching selected categories:
sha256sum <file-path> | awk '{print "sha256:" $1}'
# Compare result to manifest .files[path].hash
```

If ANY files have been modified (hash mismatch), list them and ask:

```
Modified files detected (you edited these since scaffolding):
  - {file1}
  - {file2}
  - ...

How do you want to handle modified files?
  → Skip modified files (safe — your edits are preserved)
  → Force overwrite (your edits will be replaced with the new version)
```

Wait for the user's choice. If no files are modified, skip this question and proceed with `skip` mode.

### Step 5 — Execute Upgrade

Find the upgrade script and scaffold directory:

```bash
UPGRADE_SCRIPT=$(find ~/.claude/plugins -name "upgrade.sh" -path "*/structured-agentic-coding*" 2>/dev/null | sort -V | tail -1)
SCAFFOLD_DIR=$(dirname "$UPGRADE_SCRIPT")/../.claude/scaffold
```

Run the upgrade script with the collected parameters:

```bash
bash "$UPGRADE_SCRIPT" \
  "$SCAFFOLD_DIR" \
  "$(pwd)" \
  --manifest ".claude/scaffold-manifest.json" \
  --categories "{comma-separated selected categories}" \
  --conflict-mode "{skip or force}" \
  --plugin-version "{plugin version}"
```

### Step 6 — Report Results

Parse the script output and present a summary:

```
Upgrade complete: v{old} → v{new}

  Updated:  {N} files
  Created:  {N} new files
  Skipped:  {N} files (modified by you)
  Forced:   {N} files (overwritten)
  Removed upstream: {N} files (no longer in new version — not deleted)

{If any files were skipped:}
  Skipped files (your edits preserved):
    - {file1}
    - {file2}

  Tip: To see what changed in the new templates, compare your version
  against the plugin's source templates in: {SCAFFOLD_DIR}

{If any files were removed upstream:}
  Files removed in the new version (not deleted from your project):
    - {file1}
    - {file2}

  You may want to remove these manually if they are no longer needed.
```

### Step 7 — Post-Upgrade Migration (codemap → graph)

If the upgrade crossed from a codemap-based version to a graph-based version (manifest version < 4.0 and plugin version >= 4.0), run these additional migration steps:

**7a. Offer to delete stale scaffolded files:**
Check for REMOVED_UPSTREAM entries in the upgrade output. Ask the user:
> "These files were removed in the new version (replaced by the code graph MCP server). Delete them?"
> - `.claude/agents/codebase/{PREFIX}-codemap-updater.md`
> - `.claude/commands/update-codemaps.md`

If user confirms, delete them:
```bash
rm -f ".claude/agents/codebase/{PREFIX}-codemap-updater.md"
rm -f ".claude/commands/update-codemaps.md"
```

**7b. Clean up generated codemaps:**
```
Glob("**/CODEMAP.md")
```
If any files found, ask:
> "These CODEMAP.md files were generated by the old codemap system. The code graph replaces them. Delete? [list files]"

If confirmed, delete each listed file.

**7c. Verify CLI is available:**
Run `sac-graph --help` to confirm the graph CLI is installed. If not found, run the install script:
```bash
bash "$PLUGIN_ROOT/scripts/install-graph-server.sh"
```

**7d. Add .code-graph/ to .gitignore:**
```bash
grep -q "^\.code-graph/" .gitignore 2>/dev/null || echo ".code-graph/" >> .gitignore
```

**7e. Install graph server:**
```bash
bash "$PLUGIN_ROOT/scripts/install-graph-server.sh"
```

**7f. Report:**
> "Migration complete. Graph CLI configured."
> "Run `sac-graph rebuild` to build the initial code graph, or it will auto-build on first query."
> "AGENTS.md can be regenerated with: `bash .claude/scripts/regenerate-agents-md.sh`"

## Migration: Projects Without a Manifest

If the user runs this command on a project that was scaffolded before the manifest feature existed (no `.claude/scaffold-manifest.json`), offer to generate one:

> "This project was scaffolded before version tracking was added. I can generate a manifest from your current files so future upgrades work. This will hash your current files as the baseline — any changes you've made since scaffolding will be treated as the 'original' state. Proceed?"

If the user agrees:
1. Ask for the original plugin version (default: `1.0.0`)
2. Ask for the profile used (`base` or `angular-dotnet`)
3. Scan `.claude/agents/`, `.claude/commands/`, etc. to find scaffolded files
4. Read `CLAUDE.md` to extract ALL placeholder values. The manifest must include every placeholder the templates use, or the upgrade script will leave `__PLACEHOLDER__` tokens in output files. Required placeholders for `angular-dotnet`:
   - `PREFIX` — agent filename prefix (e.g. `recruitadev`)
   - `PROJECT_NAME` — display name (e.g. `RecruitADev`)
   - `PROJECT_DESC` — short description (e.g. `recruitment management platform`)
   - `BE_DIR` — backend directory (e.g. `backend`)
   - `FE_DIR` — frontend directory (e.g. `frontend`)
   - `BE_RUN`, `BE_BUILD`, `BE_TEST`, `BE_FORMAT`, `BE_SLN`, `BE_API_PROJECT`, `BE_NAMESPACE`
   - `FE_SERVE`, `FE_BUILD`, `FE_TEST`, `FE_FORMAT`, `FE_LINT`
   - `DB_START`, `MIGRATION`, `E2E_CMD`
5. Hash all found files and generate the manifest
6. Then proceed with the normal upgrade flow
