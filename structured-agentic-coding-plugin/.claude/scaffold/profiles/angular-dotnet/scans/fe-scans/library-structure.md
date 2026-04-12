# Scan Playbook: Library Structure

Category: `library-structure` | Rules: FE-LIB-001 through FE-LIB-003

---

## FE-LIB-001 -- Libraries must be created via Nx generators

**What to check:** Every directory under `frontend/libs/` that contains source code must be a proper Nx library with a `project.json` file. A manually-created directory with just `src/index.ts` is NOT a valid Nx library.

**Why this matters:** Nx libraries created via generators are registered in the Nx workspace graph (`npx nx show projects` lists them). Without `project.json`, the library is invisible to Nx — it cannot have its own test/lint/build targets, it breaks `nx affected` analysis, and it won't appear in the dependency graph (`npx nx graph`).

### Detection

**Scan 1 -- Find all library directories:**

```
Glob pattern: "frontend/libs/*/*/src/index.ts"
```

This returns all barrel exports, which identifies all libraries.

**Scan 2 -- Check for project.json in each library:**

```
Glob pattern: "frontend/libs/*/*/project.json"
```

**Interpretation:** Compare the two lists. Any library that has `src/index.ts` but NOT `project.json` is a violation.

- **True positive:** `frontend/libs/core/routing/src/index.ts` exists but `frontend/libs/core/routing/project.json` does not
- **False positive:** None — every library must have `project.json`
- **Severity:** error

### How to Fix: Creating a Proper Nx Library

When an agent needs to create a new library, it MUST use the Nx generator. The exact command depends on the library domain and type. All commands must be run from the `frontend/` directory.

**IMPORTANT:** The generator does NOT support `--dry-run`. The agent must run the command directly.

#### Core Utility Library (no component — services, helpers, enums, models)

Use case: `@libs/core/routing`, `@libs/core/store`, `@libs/core/forms`

```bash
cd frontend && npx nx g @nx/angular:library \
  --directory=libs/core/{name} \
  --name={name} \
  --standalone \
  --skipModule \
  --skipTests \
  --flat \
  --style=none \
  --prefix=lcb \
  --skipSelector
```

**What the generator creates:**

```
libs/core/{name}/
├── project.json          ← Nx project config (targets: build, lint, test)
├── tsconfig.lib.json     ← Library-specific TypeScript config
├── tsconfig.spec.json    ← Test-specific TypeScript config
├── src/
│   ├── index.ts          ← Barrel export (public API)
│   └── lib/
│       └── {name}.component.ts  ← Default standalone component (DELETE THIS if not needed)
```

**Post-generator steps for utility libs:**

1. Delete the generated component file (`src/lib/{name}.component.ts`) — utility libs don't need it
2. Create your actual source files under `src/lib/`
3. Update `src/index.ts` to export your code
4. Verify the path alias was added to `tsconfig.json` — if not, add `"@libs/core/{name}": ["libs/core/{name}/src/index.ts"]`
5. Verify the library appears in `npx nx show projects`

#### UI Component Library (single presentational component)

Use case: `@libs/ui/sidebar`, `@libs/ui/button`, `@libs/ui/dialog`

```bash
cd frontend && npx nx g @nx/angular:library \
  --directory=libs/ui/{name} \
  --name={name} \
  --standalone \
  --skipModule \
  --style=scss \
  --changeDetection=OnPush \
  --prefix=ui \
  --flat
```

**What the generator creates:**

```
libs/ui/{name}/
├── project.json
├── tsconfig.lib.json
├── tsconfig.spec.json
├── src/
│   ├── index.ts
│   └── lib/
│       ├── {name}.component.ts       ← Standalone component with OnPush
│       ├── {name}.component.html      ← Template
│       └── {name}.component.scss      ← Styles
```

**Post-generator steps:**

1. The generated component is your starting point — edit it directly
2. Add `standalone: true` and `changeDetection: ChangeDetectionStrategy.OnPush` if not already set
3. Export the component from `src/index.ts`
4. Verify path alias in `tsconfig.json`: `"@libs/ui/{name}": ["libs/ui/{name}/src/index.ts"]`

#### Feature Library (smart components with business logic)

Use case: `@libs/features/candidates`, `@libs/features/challenges`, `@libs/features/layout`

```bash
cd frontend && npx nx g @nx/angular:library \
  --directory=libs/features/{name} \
  --name={name} \
  --standalone \
  --skipModule \
  --style=scss \
  --changeDetection=OnPush \
  --prefix=lcb \
  --flat
```

**Post-generator steps:**

1. Edit the generated component or delete it and create your own components
2. Create stores, services, sub-components under `src/lib/`
3. Export public API from `src/index.ts`
4. Verify path alias: `"@libs/features/{name}": ["libs/features/{name}/src/index.ts"]`

#### Page Library (lazy-loaded routed pages)

Use case: `@libs/pages/dashboard`, `@libs/pages/candidates`, `@libs/pages/login`

```bash
cd frontend && npx nx g @nx/angular:library \
  --directory=libs/pages/{name} \
  --name={name} \
  --standalone \
  --skipModule \
  --style=scss \
  --changeDetection=OnPush \
  --prefix=lcb \
  --flat \
  --routing \
  --lazy
```

**Post-generator steps:**

1. Create a `routes.ts` file in `src/lib/` exporting `Routes` array
2. Register in `app.routes.ts` via `loadChildren: () => import('@libs/pages/{name}').then(m => m.routes)`
3. Add the route path to `AppRoutes` enum in `@libs/core/routing`
4. Export `routes` from `src/index.ts`
5. Verify path alias: `"@libs/pages/{name}": ["libs/pages/{name}/src/index.ts"]`

### Verifying a Library is Properly Created

After running the generator, the agent MUST verify:

```bash
# 1. Library appears in Nx project list
cd frontend && npx nx show projects

# 2. project.json exists
ls libs/{domain}/{name}/project.json

# 3. Path alias exists in tsconfig.json
grep -c "@libs/{domain}/{name}" tsconfig.json

# 4. TypeScript compiles
npx tsc --noEmit --project tsconfig.app.json
```

If any check fails, the library was not properly created.

---

## FE-LIB-002 -- Library placement follows domain structure

**What to check:** Libraries must be placed under the correct domain directory.

**Scan:**

```
Glob pattern: "frontend/libs/*/src/index.ts"
```

- **True positive:** `frontend/libs/my-lib/src/index.ts` — library at libs root instead of under a domain (core/features/pages/ui)
- **False positive:** None — all libraries must be under a domain

**Domain rules:**
| Domain | Purpose | Import direction |
|--------|---------|-----------------|
| `libs/core/` | Shared utilities, services, models, enums | Imported by features, pages, ui |
| `libs/features/` | Smart components with business logic and stores | Imported by pages |
| `libs/pages/` | Lazy-loaded routed page shells | Imported only by app.routes.ts |
| `libs/ui/` | Presentational (dumb) components | Imported by features, pages |

**Dependency direction:** `pages → features → core`, `pages → ui`, `features → ui`, `features → core`. Never backwards.

- **Severity:** error

---

## FE-LIB-003 -- tsconfig path alias registered

**What to check:** Every library must have a `@libs/{domain}/{name}` path alias in `frontend/tsconfig.json`.

**Scan 1 -- Find all library barrel exports:**

```
Glob pattern: "frontend/libs/*/*/src/index.ts"
```

**Scan 2 -- Read tsconfig.json paths section:**

```
Grep pattern: "@libs/"
     path:    frontend/tsconfig.json
     output_mode: content
```

**Interpretation:** For each library found in Scan 1, extract its domain and name from the path (`libs/{domain}/{name}/src/index.ts`), then check if `@libs/{domain}/{name}` appears in tsconfig.json paths.

- **True positive:** `libs/core/routing/src/index.ts` exists but no `"@libs/core/routing"` entry in tsconfig.json
- **False positive:** None — every library needs a path alias
- **Severity:** error

**Fix:** Add to `frontend/tsconfig.json` under `compilerOptions.paths`:

```json
"@libs/{domain}/{name}": ["libs/{domain}/{name}/src/index.ts"]
```

Note: The Nx generator usually adds this automatically. If missing, it may indicate the library was created manually.

---

## FE-LIB-004 -- Library must have tsconfig.lib.json and tsconfig.spec.json

**What to check:** Every Nx library must have its own `tsconfig.lib.json` (compilation boundaries for production build) and `tsconfig.spec.json` (test compilation config) alongside `project.json`.

**Why this matters:** These files define TypeScript compilation boundaries. Without `tsconfig.lib.json`, the library cannot be built independently. Without `tsconfig.spec.json`, `nx test {lib}` cannot resolve library-specific paths.

### Detection

**Scan 1 -- Find all libraries (baseline):**

```
Glob pattern: "frontend/libs/*/*/src/index.ts"
```

**Scan 2 -- Check for tsconfig.lib.json:**

```
Glob pattern: "frontend/libs/*/*/tsconfig.lib.json"
```

**Scan 3 -- Check for tsconfig.spec.json:**

```
Glob pattern: "frontend/libs/*/*/tsconfig.spec.json"
```

**Interpretation:** Compare Scan 1 against Scan 2 and Scan 3. Any library missing either file is a violation.

- **True positive:** `libs/core/auth/src/index.ts` exists but `libs/core/auth/tsconfig.lib.json` does not
- **False positive:** None — every Nx library needs both files
- **Severity:** warning

**Fix:** The Nx generator creates these automatically. If the library was generated but files were deleted, recreate them following this pattern:

**tsconfig.lib.json:**

```json
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "../../dist/out-tsc",
    "declaration": true,
    "declarationMap": true,
    "inlineSources": true,
    "types": []
  },
  "exclude": ["**/*.spec.ts", "jest.config.ts", "**/*.test.ts"],
  "include": ["src/**/*.ts"]
}
```

**tsconfig.spec.json:**

```json
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "../../dist/out-tsc",
    "types": ["jest", "node"]
  },
  "include": ["src/**/*.spec.ts", "src/**/*.test.ts", "src/**/*.d.ts"]
}
```

---

## FE-LIB-005 -- Library must have ESLint config

**What to check:** Every Nx library must have an ESLint configuration file at its root — either `eslint.config.mjs` (flat config, preferred) or `.eslintrc.json` (legacy).

**Why this matters:** Without per-library ESLint config, `nx lint {lib}` fails and the library is excluded from `nx affected --target=lint` analysis. This means code quality regressions go undetected.

### Detection

**Scan 1 -- Find modern ESLint configs:**

```
Glob pattern: "frontend/libs/*/*/eslint.config.mjs"
```

**Scan 2 -- Find legacy ESLint configs:**

```
Glob pattern: "frontend/libs/*/*/.eslintrc.json"
```

**Interpretation:** Any library from the baseline list that has NEITHER `eslint.config.mjs` NOR `.eslintrc.json` is a violation.

- **True positive:** `libs/ui/card/src/index.ts` exists but neither ESLint config file does
- **False positive:** None
- **Severity:** warning

**Fix:** The Nx generator creates this automatically. For manual creation, use `eslint.config.mjs`:

```js
const nx = require('@nx/eslint-plugin');
const baseConfig = require('../../eslint.config.mjs');

module.exports = [...baseConfig, ...nx.configs['flat/angular'], ...nx.configs['flat/angular-template']];
```

---

## FE-LIB-006 -- No deep imports bypassing barrel export

**What to check:** All cross-library imports must use the barrel export (`@libs/{domain}/{name}`). Never import directly from a library's internal file structure.

**Why this matters:** Deep imports break encapsulation, create fragile coupling to internal file structure, and bypass the library's public API contract. When internals are refactored, deep importers break.

### Detection

**Scan 1 -- Deep barrel bypass:**

```
Grep pattern: from ['"]@libs/[^'"]+/src/
     path:    frontend/libs/
     glob:    *.ts
     output_mode: content
```

Matches imports like `from '@libs/core/auth/src/lib/auth.service'`.

**Scan 2 -- Relative cross-library imports:**

```
Grep pattern: from ['"]\.\./.*libs/
     path:    frontend/libs/
     glob:    *.ts
     output_mode: content
```

Matches imports like `from '../../core/auth/src/lib/...'`.

**Interpretation:**

- **True positive:** Any import that references `/src/lib/` or `/src/` of another library
- **False positive:** Relative imports within the same library (`from './my-service'`, `from '../models/my-model'`) — these are fine
- **Severity:** warning

**Fix:** Replace deep import with barrel import:

```typescript
// BAD
import { AuthService } from '@libs/core/auth/src/lib/auth.service';

// GOOD
import { AuthService } from '@libs/core/auth';
```

If the symbol is not exported from the barrel, add it to `src/index.ts`.

---

## FE-LIB-007 -- Library dependency direction enforced

**What to check:** Library imports must follow the dependency direction: `pages → features → core`, `pages → ui`, `features → ui`, `features → core`. Never backwards.

**Why this matters:** Backward dependencies create circular coupling, break Nx's affected analysis, and make libraries impossible to use independently. They also prevent future extraction of libraries into separate packages.

### Detection

**Scan 1 -- core/ importing from features/ (violation):**

```
Grep pattern: from ['"]@libs/features/
     path:    frontend/libs/core/
     glob:    *.ts
     output_mode: content
```

**Scan 2 -- core/ importing from pages/ (violation):**

```
Grep pattern: from ['"]@libs/pages/
     path:    frontend/libs/core/
     glob:    *.ts
     output_mode: content
```

**Scan 3 -- ui/ importing from features/ (violation):**

```
Grep pattern: from ['"]@libs/features/
     path:    frontend/libs/ui/
     glob:    *.ts
     output_mode: content
```

**Scan 4 -- ui/ importing from pages/ (violation):**

```
Grep pattern: from ['"]@libs/pages/
     path:    frontend/libs/ui/
     glob:    *.ts
     output_mode: content
```

**Scan 5 -- features/ importing from pages/ (violation):**

```
Grep pattern: from ['"]@libs/pages/
     path:    frontend/libs/features/
     glob:    *.ts
     output_mode: content
```

**Interpretation:**

- **True positive:** Any of these imports in actual TypeScript code
- **False positive:** Comments or string literals that happen to match the pattern — confirm by Reading the file
- **Severity:** error

**Allowed dependency graph:**

```
pages  ─→  features  ─→  core
  │            │
  └──→  ui  ←─┘
```

**Fix:** Extract shared code into `core/` or `ui/`. If a feature needs data from another feature, extract the shared model/service into `core/`.
