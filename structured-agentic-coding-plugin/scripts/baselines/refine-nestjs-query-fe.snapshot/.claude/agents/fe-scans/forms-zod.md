# Scan Playbook: Forms & Validation

Category: `forms` | Rules: FE-FORM-001 through FE-FORM-004

---

## FE-FORM-001 — Zod imported from 'zod/v4'

**What to check:** All Zod imports use the `zod/v4` path, never bare `zod`.

**Scan:**
```
Grep pattern: "from\\s+['\"]zod['\"]"
     path:    ./src
     output_mode: content
```

- **True positive:** `import { z } from 'zod';` anywhere in src/.
- **False positive:** None — bare `zod` always resolves to v3 for this project.
- **Confirm:** No confirmation needed.
- **Severity:** error

Also check:
```
Grep pattern: "import.*from ['\"]zod['\"]"
     path:    .
     output_mode: content
```
in `package.json` dependencies — `zod` in deps is fine, but usage must be `zod/v4`.

---

## FE-FORM-002 — zodResolver wires react-hook-form

**What to check:** `useForm` calls use `zodResolver(schema)`.

**Scan:**
```
Grep pattern: "useForm\\s*\\("
     path:    ./src
     output_mode: content
     -A:      5
```
Flag `useForm` calls without a `resolver: zodResolver(...)` prop (or with a different resolver).

- **True positive:** `useForm()` or `useForm({ defaultValues: {...} })` without resolver on a form that has validation.
- **False positive:** Forms that intentionally have no validation (rare — flag for confirmation).
- **Confirm:** Check whether the form has a schema file nearby.
- **Severity:** warning

---

## FE-FORM-003 — Custom form-validation error map used

**What to check:** Zod schemas invoke the project's custom error map for i18n-aware error messages.

**Scan:**
```
Grep pattern: "z\\.setErrorMap|setErrorMap"
     path:    ./src
     output_mode: content
```
Also:
```
Grep pattern: "form-validation"
     path:    ./src
     output_mode: content
```

- **True positive:** No call to the error-map setup (either at app init or per-form).
- **False positive:** Project sets the error map globally in `main.tsx` via `z.setErrorMap(customMap)` — in that case individual schemas don't need to call it.
- **Confirm:** Read `src/main.tsx` / `src/lib/form-validation.ts`; verify the global map is set at startup.
- **Severity:** warning

---

## FE-FORM-004 — FormProvider wraps field components

**What to check:** Components using `useFormContext()` have a `<FormProvider>` ancestor.

**Scan:**
```
Grep pattern: "useFormContext\\s*\\("
     path:    ./src
     output_mode: content
     -B:      10
```
For each match, inspect upward to the nearest component whose parent wraps with `<FormProvider>`.

- **True positive:** `useFormContext()` in a component that is rendered without a `<FormProvider>` ancestor.
- **False positive:** The component is always rendered inside a parent that wraps `<FormProvider>` — check via `sac-graph dependents` on the component.
- **Confirm:** Trace the component's usage sites; each must be under FormProvider.
- **Severity:** warning
