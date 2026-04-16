# Scan Playbook: Architecture & Structure

Category: `architecture` | Rules: BE-ARCH-001 through BE-ARCH-004

---

## BE-ARCH-001 — Feature module anatomy

**What to check:** Each feature directory must contain `entity/`, `dto/`, `service/`, `resolver/`, `<feature>.module.ts`. `assembler/` and `validators/` are optional.

**Scan:**
```
Glob pattern: ./src/*/
```
For each feature directory returned, verify the required subdirectories exist. Missing any of entity/dto/service/resolver is a violation.

- **True positive:** `src/orders/` contains `order.module.ts` and `service/` but no `resolver/`.
- **False positive:** Shared-infrastructure directories like `src/common/`, `src/filters/`, `src/guards/` intentionally deviate — they aren't feature modules.
- **Confirm:** If `<name>.module.ts` is present, it's a feature module and the anatomy rule applies.
- **Severity:** warning

---

## BE-ARCH-002 — Module exports service + TypeOrmModule

**What to check:** Every feature module exports its service AND `TypeOrmModule.forFeature([...])` so consumers can inject the repository.

**Scan:**
```
Grep pattern: "^@Module\\("
     path:    ./src
     output_mode: content
     -A:      30
```
Then for each matched module file, inspect the `exports: []` array. Flag if the service is missing or if `TypeOrmModule` is not in exports.

- **True positive:** `exports: [OrdersService]` (missing `TypeOrmModule.forFeature([OrderEntity])`).
- **False positive:** Modules that intentionally don't export (e.g., app.module.ts itself is a root composer — no exports needed).
- **Confirm:** Read the module file; compare `exports` against the declared service and imported TypeOrmModule.forFeature.
- **Severity:** warning

---

## BE-ARCH-003 — No circular module dependencies

**What to check:** Two modules must not import each other (directly or transitively).

**Scan:** This rule requires graph analysis beyond a simple Grep. Use the graph tool first; fall back to an import-map comparison.

```
Bash: sac-graph module-summary ./src --depth 2
```
Look for reciprocal imports in the output. If the graph tool is unavailable:

```
Grep pattern: "from ['\"]\\.\\./[^'\"]+(module|service)['\"]"
     path:    ./src
     output_mode: content
```
Build a directed graph of imports mentally / in scratch; any cycle is a violation.

- **True positive:** `orders.module.ts` imports `UsersModule`, and `users.module.ts` imports `OrdersModule`.
- **False positive:** A shared module imported by both — that's hub-and-spoke, not a cycle.
- **Confirm:** Build the import graph; cycles are violations regardless of length.
- **Severity:** error

---

## BE-ARCH-004 — All modules declared in AppModule

**What to check:** Every feature module under `src/<feature>/<feature>.module.ts` must be reachable from `AppModule` via its imports array (directly or via a barrel module).

**Scan:**
```
Glob pattern: ./src/**/*.module.ts
```
Then read `src/app.module.ts` and verify each feature module appears in its `imports: []` (directly or via a re-exporting module).

- **True positive:** `src/reports/reports.module.ts` exists but is not imported anywhere in `AppModule`'s imports chain.
- **False positive:** Modules intentionally used only by tests (rare; should live under `test/` instead).
- **Confirm:** Read `AppModule` and walk the import graph.
- **Severity:** error
