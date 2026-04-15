---
name: upgrade-agentic-coding
description: Upgrade an existing structured-agentic-coding scaffold to the latest plugin version — selective category updates with modification detection, plus always-active profile-migration detection.
---

# Upgrade Agentic Coding

Upgrade a previously scaffolded project to the current plugin version. Compares file hashes to detect user modifications, allows selective category upgrades, and preserves edited files.

**Always-active profile detection (new in 4.3.0):** on every upgrade, re-scan the project to check whether a different profile would now match better (e.g., a `base` project that has gained a NestJS + nestjs-query backend should migrate to `nestjs-query-be`). If a better match is detected, offer migration. This adds ~5s to every upgrade.

## Prerequisites

- Project must have `.claude/scaffold-manifest.json` (created by `/structured-agentic-coding`)
- `jq` must be installed (required by the upgrade script for manifest parsing)

## Procedure

### Step 1 — Read manifest and detect versions

```bash
cat .claude/scaffold-manifest.json
```

Extract `version`, `profile`, `scope`, and `placeholders` from the manifest. Find the plugin's current version:

```bash
PLUGIN_ROOT=$(find ~/.claude/plugins -name "plugin.json" -path "*/structured-agentic-coding*" -exec dirname {} \; 2>/dev/null | sort -V | tail -1)
PLUGIN_ROOT=$(dirname "$PLUGIN_ROOT")
cat "$PLUGIN_ROOT/.claude-plugin/plugin.json"
```

If the manifest does not exist:
> "No scaffold manifest found. Run `/structured-agentic-coding` to scaffold your project first."

Stop.

### Step 1b — Profile migration opportunity detection (always active)

Before showing the upgrade status, re-run profile detection (the same logic used by `/structured-agentic-coding` Phase 1):

1. **Context pass**: re-read README.md, CLAUDE.md, docs/*.md — extract declared facts
2. **Systematic scan**: Glob `**/package.json`, `**/*.csproj`, `**/bun.lock`, etc.
3. **Recommend profile** using the 4-profile selection logic:
   - Angular + .NET → `angular-dotnet`
   - NestJS + nestjs-query → `nestjs-query-be`
   - React + Vite + Refine + nestjs-query → `refine-nestjs-query-fe`
   - Otherwise → `base`

Compare the recommendation against the manifest's current `profile` field.

**If they match** → silent pass-through to Step 2 (standard upgrade).

**If they diverge** → print the migration offer:

```
Profile migration available: <current> → <recommended>

Reason: the project now matches the <recommended> profile better.
Detected signals:
  - <signal 1>
  - <signal 2>

Migrating keeps your placeholders (PREFIX, PROJECT_NAME, PROJECT_DESC, directory
paths) and any files you've modified. Stack-specific files (agents, rules, scans)
get regenerated for the new profile.

Do you want to:
  1. Migrate to <recommended> (then run the standard upgrade to latest version)
  2. Stay on <current> and just upgrade to the latest version
  3. Cancel
```

If user picks **1 (migrate)**: execute Step 1c (migration). If **2 (stay)**: proceed to Step 2. If **3**: exit.

### Step 1c — Execute profile migration (if accepted)

Run the upgrade script in migrate mode:

```bash
bash "$UPGRADE_SCRIPT" \
  "$SCAFFOLD_DIR" \
  "$(pwd)" \
  --manifest ".claude/scaffold-manifest.json" \
  --migrate-profile "<new-profile>" \
  --plugin-version "<version>"
```

The script:
1. Carries over the manifest's `PREFIX`, `PROJECT_NAME`, `PROJECT_DESC`, `FE_DIR`, `BE_DIR`, `SCOPE` (if the new profile's scope is compatible)
2. Re-runs detection for the new profile's manifest (prompts user for any variables that cannot be detected)
3. Scaffolds new profile-specific files (agents, rules, scans)
4. Regenerates `CLAUDE.md` with the new claude-section overlay appended
5. Preserves any file the user has modified (hash-mismatch → always skip)
6. Updates `scaffold-manifest.json` with the new profile + new file hashes

After migration, continue with Step 2 (standard upgrade) to pick up the latest plugin version's fixes.

### Step 2 — Show upgrade status report

Read `CHANGELOG.md` and extract sections between the manifest's version and the current plugin version:

```bash
cat "$PLUGIN_ROOT/CHANGELOG.md"
```

Present:

```
Upgrade available for: <project name from PREFIX>
  Profile: <manifest profile> (may have been migrated in Step 1c)
  Scope: <manifest scope>
  Current version: <manifest version>
  Available version: <plugin version>

Changes since v<manifest version>:
  <relevant CHANGELOG sections>
```

### Step 3 — Category selection

Present categories with defaults. Count files in each category from the manifest:

```
Which categories do you want to update?
  [x] Core agents — <N> files (masterplan, doc-enforcer, research, impact)
  [x] Profile agents — <N> files (BE/FE feature devs, reviewers, fixers, test writers)
  [x] Commands — <N> files
  [x] Templates — <N> files (CLAUDE.md fragments, AGENTS.md, ARCHITECTURE.md stub)
  [ ] Rules & scan playbooks — <N> files
  [ ] Config — <N> files (settings.json, anti-patterns.md)
```

Defaults selected: `agents-core`, `agents-profile`, `commands`, `templates`.
Defaults unselected: `rules-scans`, `config`.

For `profile == "base"`, omit "Profile agents" and "Rules & scan playbooks" rows.

Wait for confirmation.

### Step 4 — Modification detection and conflict decision

For each selected category, compare current file hash on disk against the manifest hash:

```bash
sha256sum <file-path> | awk '{print "sha256:" $1}'
```

If any files have been modified (hash mismatch), list them:

```
Modified files detected (you edited these since scaffolding):
  - <file1>
  - <file2>

How do you want to handle modified files?
  → Skip modified files (safe — your edits are preserved)
  → Force overwrite (your edits will be replaced with the new version)
```

Wait for choice. If no files modified, skip this question and proceed with `skip` mode.

### Step 5 — Execute upgrade

```bash
bash "$UPGRADE_SCRIPT" \
  "$SCAFFOLD_DIR" \
  "$(pwd)" \
  --manifest ".claude/scaffold-manifest.json" \
  --categories "<comma-separated selected categories>" \
  --conflict-mode "<skip|force>" \
  --plugin-version "<version>"
```

### Step 6 — Report

```
Upgrade complete: v<old> → v<new>
  Profile: <profile> (migrated from <old> | unchanged)

  Updated:  <N> files
  Created:  <N> new files
  Skipped:  <N> files (modified by you)
  Forced:   <N> files (overwritten)
  Removed upstream: <N> files (no longer in new version — not deleted)

<if any files were skipped:>
  Skipped files (your edits preserved):
    - <file>

  Tip: compare your version against the plugin's source templates in:
  <SCAFFOLD_DIR>

<if any files were removed upstream:>
  Files removed in the new version (still present in your project):
    - <file>

  Remove these manually if no longer needed.
```

### Step 7 — Post-upgrade migrations (version-specific)

If crossing major version boundaries, additional migrations may apply. See the CHANGELOG for version-specific migration notes.

## Migration: projects without a manifest

If the project was scaffolded before manifest tracking existed, offer to generate one from the current state:

> "This project was scaffolded before version tracking. I can generate a manifest from your current files so future upgrades work. This hashes your current files as the baseline — any changes you've made since scaffolding become the 'original' state. Proceed?"

If yes:
1. Ask for the original plugin version (default `1.0.0`)
2. Ask for the profile used
3. Scan `.claude/` to find scaffolded files
4. Read `CLAUDE.md` to extract placeholder values — all placeholders the current templates use must be supplied, otherwise the upgrade script will leave `__KEY__` tokens in output files
5. Hash all found files and generate the manifest
6. Proceed with the normal upgrade flow
