# Scan Playbook: Refine Framework

Category: `refine` | Rules: FE-REFINE-001 through FE-REFINE-005

---

## FE-REFINE-001 — Resources registered in <Refine>

**What to check:** Every directory under `src/resources/` must correspond to an entry in `App.tsx`'s `<Refine resources={[...]}>`.

**Scan:**
```
Glob pattern: ./src/resources/*/
```
Then read `./src/App.tsx` and compare the `resources` array entries (by `name`) against the directory names.

- **True positive:** `src/resources/invoices/` exists but no `{ name: 'invoices', ... }` in App.tsx.
- **False positive:** Directory used for shared utilities under `src/resources/_shared/` — those leading-underscore or other convention markers may be intentional.
- **Confirm:** Read App.tsx resources array; each directory in `src/resources/` without an entry is a violation.
- **Severity:** error

---

## FE-REFINE-002 — dataProvider is @refinedev/nestjs-query

**What to check:** App.tsx imports `dataProvider` from `@refinedev/nestjs-query` (or a thin project wrapper around it).

**Scan:**
```
Grep pattern: "dataProvider\\s*=|dataProvider\\s*:"
     path:    ./src/App.tsx
     output_mode: content
     -B:      2
```
Trace back to the import of `dataProvider`.

- **True positive:** `dataProvider` imported from `@refinedev/simple-rest`, `@refinedev/supabase`, or another adapter; or a custom fetch wrapper that doesn't delegate to nestjs-query.
- **False positive:** A thin project wrapper file (e.g., `src/providers/data-provider.ts`) that internally uses `@refinedev/nestjs-query`.
- **Confirm:** Read the wrapper (if any) to verify it delegates.
- **Severity:** error

---

## FE-REFINE-003 — No direct fetch() for backend

**What to check:** No `fetch()` / `axios` calls hitting the backend from resource pages, hooks, or components.

**Scan:**
```
Grep pattern: "\\b(fetch|axios)\\s*\\("
     path:    ./src/resources
     output_mode: content
```
Also scan `./src/hooks` and `./src/components`.

- **True positive:** `fetch('/api/orders')` in a resource page or hook.
- **False positive:** `fetch()` against a non-backend endpoint (public CDN, external third-party) — OK but prefer documenting why.
- **Confirm:** Read the call target; if it's the project's backend API, it's a violation.
- **Severity:** warning

---

## FE-REFINE-004 — authProvider wired to Firebase

**What to check:** App.tsx `authProvider` delegates to Firebase.

**Scan:**
```
Grep pattern: "authProvider"
     path:    ./src/App.tsx
     output_mode: content
     -B:      2
     -A:      5
```
Then read the provider file (typically `src/providers/auth-provider.ts`) and confirm it uses `firebase/auth`.

- **True positive:** authProvider with hardcoded login logic not calling Firebase.
- **False positive:** Provider wraps Firebase behind a service layer — OK.
- **Confirm:** Trace `provider.login` / `provider.check` to see if Firebase Auth is called.
- **Severity:** error

---

## FE-REFINE-005 — accessControlProvider set

**What to check:** App.tsx `<Refine>` passes an `accessControlProvider` that performs real checks.

**Scan:**
```
Grep pattern: "accessControlProvider"
     path:    ./src/App.tsx
     output_mode: content
     -A:      5
```
If missing, that's a violation. If present, read the provider and check for hardcoded `{ can: true }`.

- **True positive:** No accessControlProvider in the <Refine> props, or provider returns `{ can: true }` unconditionally.
- **False positive:** Provider exists and performs role-based checks.
- **Confirm:** Read the provider source; compare checks against known roles in the backend.
- **Severity:** warning
