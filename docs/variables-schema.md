# `variables.json` — Profile Manifest Schema

This document defines the contract for per-profile `variables.json` manifests under `structured-agentic-coding-plugin/.claude/scaffold/profiles/<profile-name>/variables.json`.

The manifest declares **what placeholders the profile uses**, **how to detect their values from the target project**, and **how scope (`fe`/`be`/`fullstack`) gates which variables apply**. The `structured-agentic-coding` skill loads the manifest of the chosen profile, runs each variable's detection strategy, builds a confirmation table for the user, and passes the resolved values to `scaffold.sh`.

---

## Top-level shape

```json
{
  "profile": "<profile-name>",
  "scope": "fe" | "be" | "fullstack",
  "context_hints": [ <ContextHint>, ... ],
  "variables": [ <Variable>, ... ]
}
```

| Field | Required | Description |
|---|---|---|
| `profile` | yes | Must match the directory name (`profiles/<name>/`). |
| `scope` | yes | The scope this profile is designed for. `fullstack` profiles support `SCOPE=fe\|be\|fullstack` at scaffold time; single-stack profiles only support their declared scope. |
| `context_hints` | optional | Fact-extraction rules that pre-populate variable defaults from documentation files (README, CLAUDE.md, docs/). Run BEFORE the systematic detection pass. |
| `variables` | yes | Array of variable definitions. Each entry resolves to one `__KEY__` placeholder. |

---

## `Variable` entry

```json
{
  "key": "BE_BUILD",
  "label": "Backend build command",
  "scope": "be",
  "type": "string",
  "required": true,
  "required_if": { "DB_MANAGED": false },
  "default": "npm run build",
  "detect": [ <DetectStrategy>, ... ]
}
```

| Field | Required | Description |
|---|---|---|
| `key` | yes | Placeholder identifier. Matches `__<KEY>__` tokens in templates. UPPER_SNAKE_CASE. |
| `label` | optional | Human-readable label shown in the confirmation table. Defaults to `key`. |
| `scope` | yes | One of `common`, `fe`, `be`. Variables with `scope: common` always apply. `fe`/`be` only apply when the active SCOPE matches or is `fullstack`. |
| `type` | optional | One of `string` (default), `boolean`, `url-or-path`. Used by the skill to validate user input. |
| `required` | optional, default `true` | If `true` and detection produces no value, the variable is presented as `⚠️ TODO` in the confirmation table for user input. If `false`, missing values become the literal string `TODO: configure`. |
| `required_if` | optional | Conditional requirement. Object mapping other variable keys to the value they must have for this one to be required. Example: `{ "DB_MANAGED": false }` means this variable is required only if `DB_MANAGED` resolved to `false`. |
| `default` | optional | Static fallback applied if no `detect` strategy produces a value. |
| `detect` | optional | Ordered array of detection strategies. The first one that produces a non-empty value wins. |

---

## `DetectStrategy` entries

Detection strategies are evaluated in order. The first non-null result is the variable's value. If all fail, `default` is applied; if no `default`, `required`/`required_if` decides whether the variable is flagged for user input.

### `package-json-script`

Read a script from the target project's `package.json`.

```json
{
  "type": "package-json-script",
  "file": "package.json",
  "script": "build",
  "runtime_prefix": true
}
```

| Field | Description |
|---|---|
| `file` | Optional, default `package.json`. Resolved relative to target project root. |
| `script` | Required. Name of the script under `"scripts"`. |
| `runtime_prefix` | Optional, default `false`. If `true`, the resulting value is prefixed with the detected runtime (`bun run` if `BE_RUNTIME=bun`, otherwise `npm run`). Useful for giving the user a runnable command, not just the script body. |

### `glob-present`

Check whether at least one file matches a glob pattern.

```json
{
  "type": "glob-present",
  "pattern": "**/firebase.json",
  "value_when_true": "true",
  "value_when_false": "false"
}
```

| Field | Description |
|---|---|
| `pattern` | Required. Glob pattern resolved relative to target root. |
| `value_when_true` | Optional, default `"true"`. Returned when at least one match exists. |
| `value_when_false` | Optional. If omitted, no value is produced (detection moves to next strategy). If present, returned when no matches. |

### `glob-absent`

Inverse of `glob-present`. Useful for boolean variables like `DB_MANAGED` (true when no `docker-compose*.yml` exists).

```json
{
  "type": "glob-absent",
  "pattern": "**/docker-compose*.yml",
  "value_when_absent": "true",
  "value_when_present": "false"
}
```

### `regex-in-file`

Search for a regex in a specific file. The first capture group is returned.

```json
{
  "type": "regex-in-file",
  "file": "graphql.config.ts",
  "pattern": "schema:\\s*['\"]([^'\"]+)['\"]"
}
```

If the regex matches but has no capture group, the entire match is returned.

### `docker-compose-service`

Build a `docker compose ... up -d` command pointing at the first compose file containing one of the listed service hints.

```json
{
  "type": "docker-compose-service",
  "service_hint": "postgres|mysql|mariadb"
}
```

Produces a value like `docker compose -f docker/docker-compose.yml up -d`. The `service_hint` is a regex that matches against service names in the compose file.

### `static`

Always return a fixed value. Useful as a final fallback in the `detect[]` chain.

```json
{
  "type": "static",
  "value": "bun run build"
}
```

### `context-inferred`

Pull the value from the context-pass results (see `context_hints` below). Useful when the same fact (e.g., "uses Bun") drives multiple variables.

```json
{
  "type": "context-inferred",
  "from": "BE_RUNTIME"
}
```

The `from` field references a key set by a `context_hints` entry's `implies` block.

---

## `ContextHint` entries

Context hints run BEFORE the systematic `detect[]` pass. They scan high-signal documentation (README, CLAUDE.md, docs/) for declared facts that override or qualify what glob-based detection would find. This matters because some facts only exist as prose: e.g., a project's CLAUDE.md may say "Bun is required" without that being detectable from `package.json` alone.

```json
{
  "file": "CLAUDE.md",
  "grep": "(?i)bun",
  "implies": {
    "BE_RUNTIME": "bun",
    "FE_RUNTIME": "bun"
  }
}
```

| Field | Description |
|---|---|
| `file` | Required. File to scan, relative to target project root. Typical values: `README.md`, `CLAUDE.md`, `docs/**/*.md`. Glob patterns supported. |
| `grep` | Required. Case-insensitive regex (use `(?i)` inline flag for explicit case-insensitivity). If matched, `implies` keys are set in the context-pass results. |
| `implies` | Required. Object of `key: value` pairs added to the context-pass results when `grep` matches. These values become the source for `detect: [{ type: "context-inferred", from: "..." }]` entries and also raise the priority of matching `static` defaults. |

---

## Worked examples

### Example 1 — Simple variable with detection chain

```json
{
  "key": "BE_BUILD",
  "label": "Backend build command",
  "scope": "be",
  "required": true,
  "detect": [
    { "type": "package-json-script", "script": "build", "runtime_prefix": true },
    { "type": "static", "value": "bun run build" }
  ]
}
```

Resolution: try the `build` script in `package.json` first (with runtime prefix). If `package.json` has no `build` script, fall back to the literal `bun run build`.

### Example 2 — Conditional variable

```json
{
  "key": "DB_MANAGED",
  "label": "Database is managed externally",
  "scope": "be",
  "type": "boolean",
  "detect": [
    { "type": "glob-absent", "pattern": "**/docker-compose*.yml" }
  ]
},
{
  "key": "DB_START",
  "label": "Local database start command",
  "scope": "be",
  "required_if": { "DB_MANAGED": false },
  "detect": [
    { "type": "docker-compose-service", "service_hint": "postgres|mysql|mariadb" }
  ]
}
```

Resolution: `DB_MANAGED` is boolean — true if no `docker-compose*.yml` files are present (managed DB scenario like Cloud SQL). `DB_START` is only required when `DB_MANAGED=false`; the skill skips it from the confirmation table when DB is managed.

### Example 3 — Context-inferred variable

```json
{
  "context_hints": [
    {
      "file": "CLAUDE.md",
      "grep": "(?i)bun (required|only|mandatory)",
      "implies": { "BE_RUNTIME": "bun" }
    }
  ],
  "variables": [
    {
      "key": "BE_RUNTIME",
      "label": "Backend runtime (bun|node)",
      "scope": "be",
      "detect": [
        { "type": "context-inferred", "from": "BE_RUNTIME" },
        { "type": "glob-present", "pattern": "bun.lock", "value_when_true": "bun" },
        { "type": "static", "value": "node" }
      ]
    }
  ]
}
```

Resolution: if the project's CLAUDE.md says "Bun required" (or similar), `BE_RUNTIME=bun` from the context pass. Otherwise, fall back to `bun.lock` presence detection. Final fallback: assume `node`. The context hint takes precedence so prose-declared facts beat lockfile heuristics.

---

## Variable scope rules

| `variables[].scope` | Active SCOPE: `fullstack` | Active SCOPE: `be` | Active SCOPE: `fe` |
|---|---|---|---|
| `common` | applied | applied | applied |
| `be` | applied | applied | skipped |
| `fe` | applied | skipped | applied |

A profile's top-level `scope` constrains what the profile supports:
- `scope: be` profiles can only be scaffolded with `SCOPE=be`.
- `scope: fe` profiles can only be scaffolded with `SCOPE=fe`.
- `scope: fullstack` profiles support all three SCOPEs (the legacy `angular-dotnet` profile and any future cross-stack profile).

---

## Migration from current hardcoded skill (4.2.0 → 4.3.0)

Before this schema, the `structured-agentic-coding/SKILL.md` hardcoded the variable list inside its Phase 2 detection prose. The 4.3.0 release moves all variables into per-profile manifests. The mapping for `angular-dotnet`:

| Current placeholder | New `variables.json` entry |
|---|---|
| `PREFIX`, `PROJECT_NAME`, `PROJECT_DESC` | `scope: common`, asked directly by the skill (3 fixed questions). Not in the per-profile manifest. |
| `FE_DIR`, `BE_DIR` | `scope: fe` / `scope: be`, detected from project layout. |
| `FE_SERVE` | `scope: fe`, `package-json-script` (script: `start` or `serve`) with Nx awareness. |
| `FE_BUILD`, `FE_TEST`, `FE_FORMAT`, `FE_LINT` | `scope: fe`, `package-json-script` per script name. |
| `BE_BUILD` | `scope: be`, `static: dotnet build <BE_SLN>` once `BE_SLN` is resolved. |
| `BE_TEST`, `BE_RUN`, `BE_FORMAT` | `scope: be`, similar `static`-with-substitution pattern. |
| `BE_SLN` | `scope: be`, `glob-present` on `**/*.sln` (returns the path). |
| `BE_API_PROJECT` | `scope: be`, `regex-in-file` on the API csproj for `<RootNamespace>` or path heuristic. |
| `BE_NAMESPACE` | `scope: be`, derived from `BE_SLN` filename (e.g., `MyApp.sln` → `MyApp`). |
| `DB_START` | `scope: be`, `docker-compose-service` with `service_hint: postgres|mysql\|mariadb`. |
| `MIGRATION` | `scope: be`, `static` template with `BE_API_PROJECT` substitution. |
| `E2E_CMD` | `scope: fe`, `glob-present` on `playwright.config.*` → `cd <FE_DIR> && npx playwright test`. |

The skill no longer holds any of these strings in its prose; Phase 2 of the skill becomes "load `<profile>/variables.json` and run the detection pipeline". The flow is identical from the user's perspective.

---

## Implementation notes

- **Detection runs once.** Results are cached for the duration of the scaffolding session.
- **User overrides are final.** If the user edits a value in the confirmation table, that value is used regardless of detection results.
- **Unresolved required variables** are flagged in the confirmation table with `⚠️` and require the user to either provide a value or explicitly type `skip` (which becomes `TODO: configure` in scaffolded files).
- **Manifest validation** is the responsibility of the loader; malformed manifests should fail loudly with a clear message identifying the offending field.
- **Adding a new profile** requires only writing `variables.json`, `claude-section.md`, agent files, rules, and scans. No changes to `scaffold.sh` or the skill.
