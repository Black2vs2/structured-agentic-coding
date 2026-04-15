# Scan Playbook: Code Hygiene

Category: `hygiene` | Rules: FE-HYGIENE-001 through FE-HYGIENE-006

---

## FE-HYGIENE-001 -- No console/debugger

**What to check:** Flag `console.log`, `console.warn`, `console.error`, `console.debug`, `console.info`, and `debugger` statements. These are dev artifacts that can leak information.

**Scan:**

```
Grep pattern: "console\.(log|warn|error|debug|info)\(|debugger\b"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `console.log('candidate:', candidate);` — dev artifact
- **True positive:** `debugger;` — debug breakpoint left in code
- **False positive:** Same in `*.spec.ts` files — test files are excluded from scope
- **Confirm:** Check file path to exclude test files. Any match in non-test `.ts` files is a violation.
- **Severity:** warning

---

## FE-HYGIENE-002 -- No commented-out code

**What to check:** Flag 3+ consecutive lines of commented-out code. Git history preserves everything — no need to keep dead code in comments.

**Scan:**

```
Grep pattern: "^\s*//\s*(const |let |var |import |export |if |else |for |while |return |await |this\.|inject\(|@Component|@Input)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **Interpretation:** This finds comments that look like TypeScript code (starting with common keywords). If 3+ consecutive matches appear in the same file at adjacent line numbers, that's commented-out code.
- **True positive:** Three consecutive lines like:
  ```
  // const items = this.store.items();
  // if (items.length > 0) {
  //   this.router.navigate(['/items', items[0].id]);
  ```
- **False positive:** A single `// return early if...` design comment — not commented-out code
- **False positive:** JSDoc or documentation comments — not dead code
- **Confirm:** Check if matches are consecutive lines in the same file. Single-line matches are not violations.
- **Severity:** info

---

## FE-HYGIENE-003 -- No unused imports/variables/dead code

**What to check:** Flag unused imports, variables, private methods, unreachable code.

**Note:** This rule is primarily handled by TypeScript compiler (`noUnusedLocals`, `noUnusedParameters`) and ESLint (`@typescript-eslint/no-unused-vars`). Grep-based scanning has limited effectiveness for this check.

**Priority:** Low — skip unless budget allows. The IDE/linter handles this much better than Grep.

**Scan (low priority, optional):**

```
Grep pattern: "^import\s+\{"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **Interpretation:** Can heuristically check for imports that don't appear elsewhere in the file, but this is unreliable and time-consuming.
- **Severity:** info

---

## FE-HYGIENE-004 -- No TODO/FIXME/HACK

**What to check:** Flag TODO, FIXME, HACK, XXX, TEMP, WORKAROUND comments. These should be tracked issues.

**Scan:**

```
Grep pattern: "//\s*(TODO|FIXME|HACK|XXX|TEMP|WORKAROUND)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `// TODO: add proper validation` — should be a tracked issue
- **True positive:** `// HACK: workaround for PrimeNG bug` — should be tracked
- **True positive:** `// FIXME: this breaks with null values` — should be tracked
- **False positive:** None — all of these should be tracked issues or removed
- **Confirm:** No confirmation needed. Any match is a violation.
- **Suggested fix:** Remove the comment and create a tracked issue, or add an issue reference: `// TODO(#123): add validation`
- **Severity:** info

---

## FE-HYGIENE-005 -- No any type

**What to check:** Flag `: any`, `<any>`, `as any` usage. `any` disables type checking. Exclude test files and generated code.

**Scan:**

```
Grep pattern: ":\s*any\b|<any>|as any"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `data: any` in a component or service
- **True positive:** `result as any` type assertion
- **True positive:** `items: Array<any>` generic with any
- **False positive:** Same in `*.spec.ts` files — test files may use any for mocking
- **False positive:** Same in `frontend/libs/core/api/src/lib/generated/` — generated code is auto-generated
- **Confirm:** Check file path to exclude test files and generated code. In non-excluded files, any `any` usage is a violation.
- **Suggested fix:** Replace with the proper type from the API client or domain model. Use `unknown` with type guards when the type is truly unknown. Use generics when the type varies.
- **Severity:** warning

---

## FE-HYGIENE-006 -- Docs on complex logic only

**What to check:** Do NOT flag missing JSDoc. Only flag complex functions without a why-comment explaining the reasoning.

**Note:** This rule is subjective and difficult to automate via Grep. It applies during contextual verification when the reviewer reads complex code blocks.

**Priority:** Low — do not run automated scan. During Phase 2 contextual verification, if you encounter complex logic (e.g., multi-step data transformations, non-obvious algorithm choices, workarounds), check for explanatory comments.

**Severity:** info

No automated scan for this rule.
