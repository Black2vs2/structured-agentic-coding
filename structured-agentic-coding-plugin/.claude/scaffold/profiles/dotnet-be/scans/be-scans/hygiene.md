# Scan Playbook: Code Hygiene

Category: `hygiene` | Rules: BE-HYGIENE-001 through BE-HYGIENE-006

---

## BE-HYGIENE-001 — No console/debug artifacts

**What to check:** Flag `Console.Write*`, `Debug.Write*`, `Debugger.Break`, `Debugger.Launch`, `Trace.Write*`. Use `ILogger` instead.

**Scan:**
```
Grep pattern: "(Console\.Write|Debug\.Write|Debugger\.(Break|Launch)|Trace\.Write)"
     path:    backend/src
     output_mode: content
```
- **True positive:** `Console.WriteLine("Processing item...");` — should use `_logger.LogInformation`
- **True positive:** `Debugger.Launch();` — debug artifact left in code
- **False positive:** None — these should never appear in production ASP.NET code
- **Confirm:** No confirmation needed. Any match in `backend/src` is a violation.
- **Severity:** warning

---

## BE-HYGIENE-002 — No commented-out code

**What to check:** Flag 3+ consecutive lines of commented-out code. Git history preserves everything — no need to keep dead code in comments.

**Scan:**
```
Grep pattern: "^\s*//\s*(var |await |public |private |protected |return |if |else |for |while |try |catch |using )"
     path:    backend/src
     output_mode: content
```
- **Interpretation:** This finds comments that look like code (starting with common C# keywords). If 3+ consecutive matches appear in the same file at adjacent line numbers, that's commented-out code.
- **True positive:** Three consecutive lines like:
  ```
  // var result = await db.Entities.FirstOrDefaultAsync(...);
  // if (result == null) throw new NotFoundException();
  // return result;
  ```
- **False positive:** A single `// return early if...` design comment — not commented-out code
- **False positive:** XML documentation comments (`/// <summary>`) — these are doc comments, not dead code
- **Confirm:** Check if matches are consecutive lines in the same file. Single-line matches are not violations.
- **Severity:** info

---

## BE-HYGIENE-003 — No TODO/FIXME/HACK

**What to check:** Flag `TODO`, `FIXME`, `HACK`, `XXX`, `TEMP`, `WORKAROUND` comments. These should be tracked issues instead.

**Scan:**
```
Grep pattern: "//\s*(TODO|FIXME|HACK|XXX|TEMP|WORKAROUND)"
     path:    backend/src
     output_mode: content
```
- **True positive:** `// TODO: add proper validation` — should be a tracked issue
- **True positive:** `// HACK: temporary workaround for timezone bug` — should be tracked
- **False positive:** None — all of these should be tracked issues
- **Confirm:** No confirmation needed. Any match is a violation.
- **Suggested fix:** Create a tracked issue and remove the comment, or add an issue reference: `// TODO(#123): ...`
- **Severity:** info

---

## BE-HYGIENE-004 — No unused imports/dead code

**What to check:** Flag unused `using` statements, unused variables, unused private methods, unreachable code.

**Scan 1 — Common unused import patterns:**
```
Grep pattern: "^using System\.Linq;$"
     path:    backend/src
     output_mode: content
```
Note: Unused imports are generally caught by the IDE/compiler. This scan has limited value via Grep alone.

**Scan 2 — Unused private methods (heuristic):**
```
Grep pattern: "private\s+(static\s+)?(async\s+)?(\w+)\s+(\w+)\("
     path:    backend/src
     output_mode: content
```
- **Interpretation:** For each private method found, grep for its name to see if it's called elsewhere in the same file. If no callers, it may be unused.
- **Priority:** LOW — skip this scan unless remaining turn budget. The compiler/IDE handles this better.
- **Severity:** info

---

## BE-HYGIENE-005 — Collection expressions over ToList/ToArray

**What to check:** Flag `.ToList()` and `.ToArray()` when assigning to a collection property that can accept a collection expression. Use C# 12 `[.. source]` syntax instead. Flag `new List<T> { items }` when `[items]` works.

**Scan 1 — ToList/ToArray assignments:**
```
Grep pattern: "\.(ToList|ToArray)\(\)"
     path:    backend/src/__BE_NAMESPACE__.Application
     output_mode: content
```
- **True positive:** `Items = input.Items.ToList()` — should be `Items = [.. input.Items]`
- **True positive:** `var items = list.Where(...).ToList()` when assigned to a `List<T>` or collection property
- **False positive:** `.ToList()` or `.ToArray()` as part of an EF Core query chain (`.Where(...).ToListAsync()`) — these are DB materialization, NOT collection conversion. **Do NOT flag `ToListAsync()` or `ToArrayAsync()`.**
- **False positive:** `.ToList()` passed directly to a method parameter that requires `List<T>` — collection expression may not work there
- **Confirm:** Check if the `.ToList()` is on a LINQ-to-Objects operation (in-memory) vs LINQ-to-Entities (EF Core query). Only flag in-memory cases.
- **Severity:** info

**Scan 2 — new List<T> { ... }:**
```
Grep pattern: "new List<\w+>\s*\{"
     path:    backend/src
     output_mode: content
```
- **True positive:** `new List<string> { "a", "b", "c" }` — should be `["a", "b", "c"]`
- **False positive:** None for simple cases
- **Severity:** info

---

## BE-HYGIENE-006 — No redundant null-coalescing for defaulted properties

**What to check:** When assigning to an entity property that has a default initializer (e.g., `List<string> Items { get; set; } = []`), flag null-coalescing fallback to the same default.

**Scan:**
```
Grep pattern: "\?\?\s*(\[\]|new List|new \w+\[\]|Array\.Empty)"
     path:    backend/src/__BE_NAMESPACE__.Application
     output_mode: content
```
- **True positive:** `Items = input.Items ?? []` when the entity's `Items` property already defaults to `[]`
- **False positive:** `var items = input.Items ?? []` for a local variable — no entity default to rely on
- **Confirm:** When you find a match:
  1. Identify the entity property being assigned to
  2. Check the entity class definition for a default initializer on that property
  3. If the property has a default (e.g., `= []` or `= new List<string>()`), the `??` is redundant
- **Severity:** info
