# Scan Playbook: Component Structure

Category: `component-structure` | Rules: FE-COMP-001 through FE-COMP-007

---

## FE-COMP-001 -- Standalone components only

**What to check:** Every `@Component` must have `standalone: true`. Flag any component without it or declared in an NgModule.

**Scan 1 -- Find all component files:**

```
Grep pattern: "@Component\("
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.ts"
```

**Scan 2 -- Find standalone declarations:**

```
Grep pattern: "standalone:\s*true"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.component.ts"
```

- **Interpretation:** Compare the two file lists. Component files without `standalone: true` are violations.
- **True positive:** `@Component({ selector: 'app-list', templateUrl: '...' })` — missing standalone
- **False positive:** `@Component({ standalone: true, selector: 'app-list', ... })` — correct
- **Confirm:** Read the component decorator to verify standalone is present. In Angular 19+, standalone defaults to true if not specified, but this codebase requires explicit declaration for clarity.
- **Severity:** warning

**Scan 3 -- NgModule declarations (should not exist):**

```
Grep pattern: "@NgModule\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** Any `@NgModule` with `declarations` array containing components
- **False positive:** `@NgModule` used only for third-party module configuration (rare, acceptable)
- **Confirm:** Read the NgModule to check if it declares components (violation) or only configures providers (borderline acceptable).
- **Severity:** warning

---

## FE-COMP-002 -- Separate files for feature/page components

**What to check:** In `features/` and `pages/` libraries, components must use `templateUrl` and `styleUrl` (external files). Inline templates are only acceptable in `ui/` library.

**Scan:**

```
Grep pattern: "\btemplate\s*:"
     path:    frontend/libs
     output_mode: content
     glob:    "*.component.ts"
```

- **True positive:** `template: '<div>...</div>'` in a file under `frontend/libs/features/` or `frontend/libs/pages/`
- **False positive:** Same code in `frontend/libs/ui/` — inline templates are acceptable for small shared UI components
- **False positive:** `templateUrl:` — this is the correct pattern, not a match
- **Confirm:** Check the file path. If the match is in `features/` or `pages/`, it's a violation. If in `ui/`, it's acceptable.
- **Severity:** info

---

## FE-COMP-003 -- Concise folder naming

**What to check:** Flag folders whose name starts with the parent folder name (e.g., `challenges/challenges-list/` should be `challenges/list/`).

**Scan:**
This rule requires Glob inspection, not Grep. Use Glob to list folders and check naming:

```
Glob pattern: "frontend/libs/features/**/*/index.ts"
     or:      "frontend/libs/pages/**/*/index.ts"
```

- **Interpretation:** For each folder found, check if the folder name starts with its parent folder name. Example: `frontend/libs/features/candidates/candidates-list/` — `candidates-list` starts with `candidates`, should be `list`.
- **True positive:** `challenges/challenges-list/` — redundant prefix
- **False positive:** `candidates/candidate-form/` — the `candidate` prefix adds meaning (singular vs plural) and is acceptable
- **Confirm:** Check if removing the parent prefix still produces a meaningful folder name.
- **Severity:** info

---

## FE-COMP-004 -- ChangeDetectionStrategy.OnPush always

**What to check:** Every `@Component` must have `changeDetection: ChangeDetectionStrategy.OnPush`.

**Scan 1 -- Find all component files:**

```
Grep pattern: "@Component\("
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.component.ts"
```

**Scan 2 -- Find OnPush declarations:**

```
Grep pattern: "ChangeDetectionStrategy\.OnPush|changeDetection:\s*ChangeDetectionStrategy\.OnPush"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.component.ts"
```

- **Interpretation:** Compare the two file lists. Component files without OnPush are violations.
- **True positive:** Component file with `@Component({...})` but no `changeDetection: ChangeDetectionStrategy.OnPush`
- **False positive:** None — all components must use OnPush
- **Confirm:** No confirmation needed if the file is missing from the OnPush scan results.
- **Severity:** warning

---

## FE-COMP-005 -- File and class naming conventions

**What to check:** Signal variables should not have `$` suffix. Observable variables must have `$` suffix.

**Scan 1 -- Signal variables with $ suffix:**

```
Grep pattern: "\$\s*=\s*(signal|computed|input|output|viewChild|contentChild|model)\b"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `items$ = signal<Item[]>([])` — signal should not have `$` suffix
- **False positive:** `items$ = this.store.items$` — if it's wrapping an Observable, `$` is correct for the Observable reference
- **Confirm:** Verify the variable is assigned a signal function (violation) vs an Observable (acceptable).
- **Severity:** info

**Scan 2 -- Observable variables without $ suffix (heuristic):**

```
Grep pattern: ":\s*Observable<"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **Interpretation:** Check if the variable name ends with `$`. Variables typed as `Observable<T>` should have the `$` suffix.
- **Priority:** Low — difficult to enforce via Grep alone. IDE/linter handles better.
- **Severity:** info

---

## FE-COMP-006 -- Selector prefix handled by ESLint

**What to check:** Skip — ESLint handles this via `@angular-eslint/component-selector`.

No scan needed. Do NOT flag selector prefix issues. Existing tooling covers this rule.

---

## FE-COMP-007 -- One concern per folder

**What to check:** Each distinct concern (component, dialog, service group, interceptor group, guard group) must live in its own subfolder. Flag folders that mix unrelated files side-by-side.

### Detection

**Scan 1 -- Multiple components in the same folder:**

```
Glob pattern: "frontend/libs/**/*.component.ts"
```

Group results by parent folder. Any folder containing 2+ different `*.component.ts` files is a violation.

- **True positive:** `grading-rubric-form/grading-rubric-form.component.ts` and `grading-rubric-form/rubric-json-dialog.component.ts` in the same folder — the dialog should be in `grading-rubric-form/rubric-json-dialog/rubric-json-dialog.component.ts`
- **False positive:** None — each component gets its own folder
- **Severity:** warning

**Scan 2 -- Mixed concern types flat in lib root:**

```
Glob pattern: "frontend/libs/core/*/src/lib/*.ts"
```

For each core library's `src/lib/` root, check if it contains files from different concern categories:

- `*.guard.ts` → should be in `guards/` subfolder (if 2+)
- `*.interceptor.ts` → should be in `interceptors/` subfolder (if 2+)
- `*.service.ts` → acceptable at lib root (the lib's primary service)
- `*.pipe.ts` → should be in `pipes/` subfolder (if 2+)
- `*.directive.ts` → should be in `directives/` subfolder (if 2+)

- **True positive:** `core/auth/src/lib/` contains `auth.interceptor.ts` and `error.interceptor.ts` loose alongside `auth.guard.ts` and `auth.service.ts` — interceptors should be in `interceptors/`, guards in `guards/`
- **False positive:** A single file of a type (e.g., one guard alone) at lib root is acceptable — subfolders are for grouping 2+ files of the same type
- **Confirm:** Count files per concern type. If a concern type has 2+ files, they should be grouped.
- **Severity:** info

**Scan 3 -- Dialog/modal components not in own subfolder:**

```
Grep pattern: "dialog|modal"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.component.ts"
```

For each match, check if the dialog component lives in its own named subfolder.

- **True positive:** `grading-rubric-form/rubric-json-dialog.component.ts` — dialog is inside the form folder, should be `grading-rubric-form/rubric-json-dialog/rubric-json-dialog.component.ts`
- **False positive:** `create-invite-dialog/create-invite-dialog.component.ts` — dialog already in its own folder
- **Confirm:** Check if the parent folder name matches the dialog component name (correct) or is a different component's folder (violation).
- **Severity:** warning

### What is acceptable in the same folder

- A component's own files: `.component.ts`, `.component.html`, `.component.scss`, `.component.spec.ts`
- A component's co-located store: `.store.ts`, `.store.spec.ts`
- A single shared utility at lib root: `validators.ts`, `utils.ts` (only if used by multiple siblings)
- `routes.ts` at the lib root
- `index.ts` barrel exports
