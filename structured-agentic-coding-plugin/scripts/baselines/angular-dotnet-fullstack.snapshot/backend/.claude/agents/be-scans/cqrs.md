# Scan Playbook: CQRS & MediatR

Category: `cqrs` | Rules: BE-CQRS-001 through BE-CQRS-007

---

## BE-CQRS-001 — Primary constructors

**What to check:** Handlers should use C# 12 primary constructors. Flag traditional constructors with manual field assignments.

**Scan 1 — Find traditional constructor patterns:**
```
Grep pattern: "private readonly"
     path:    backend/src/App.Application
     output_mode: content
```
- **True positive:** `private readonly AppDbContext _db;` followed by a constructor that assigns `_db = db;`
- **False positive:** `private readonly` for constants or pre-computed values that are NOT constructor-injected dependencies
- **Confirm:** If matches found, Read the file to check if there's a traditional constructor doing DI. If the class uses `class Handler(AppDbContext db)` syntax (primary constructor), it's correct even if there are other `private readonly` fields.
- **Severity:** info

**Scan 2 — Verify primary constructor usage:**
```
Grep pattern: "class \w+.*\(.*\)\s*:\s*IRequestHandler"
     path:    backend/src/App.Application
     output_mode: content
```
- **Interpretation:** This finds handlers already using primary constructors. Cross-reference with scan 1 — handlers NOT in scan 2 results but present as handler classes may be using traditional constructors.

---

## BE-CQRS-002 — Unit return for side-effect commands

**What to check:** Do NOT flag `Unit` returns from handlers. Flag `IActionResult` or `ActionResult` returns from handlers.

**Scan:**
```
Grep pattern: "IRequestHandler<\w+,\s*(IActionResult|ActionResult)"
     path:    backend/src/App.Application
     output_mode: content
```
- **True positive:** `class Handler : IRequestHandler<MyCommand, IActionResult>` — ASP.NET type in Application layer
- **False positive:** None — IActionResult/ActionResult should never appear as handler return types
- **Confirm:** No confirmation needed.
- **Severity:** warning

---

## BE-CQRS-003 — Primitive returns acceptable

**What to check:** Do NOT flag `Guid`/`string`/`int`/`bool` handler returns. Flag `IActionResult`/`object` returns.

**Scan:**
```
Grep pattern: "IRequest<(object|IActionResult|ActionResult)>"
     path:    backend/src/App.Application
     output_mode: content
```
- **True positive:** `record MyCommand : IRequest<object>` — untyped return
- **False positive:** None
- **Confirm:** No confirmation needed.
- **Severity:** warning

---

## BE-CQRS-004 — Handler orchestration OK if simple

**What to check:** Do NOT flag clear sequential multi-operation handlers. Flag handlers with 3+ nesting levels of control flow.

**Scan:** This cannot be reliably detected via Grep. Skip unless you have remaining turn budget.

**Manual check approach (if budget allows):**
1. Read a few of the largest handler files (by line count — use `Glob` then check file sizes)
2. Look for deeply nested `if`/`foreach`/`try` blocks (3+ levels)
- **Severity:** info

---

## BE-CQRS-005 — Commands may read DB

**What to check:** Do NOT flag database reads (`FirstOrDefaultAsync`, `ToListAsync`, etc.) inside command handlers.

**Action:** This is a "do not flag" rule. No scanning needed. Remember this when reviewing other scan results — if you see a command handler reading from the database, that is NOT a violation.

---

## BE-CQRS-006 — Pipeline behaviors for repeated patterns

**What to check:** Suggest a pipeline behavior when the same boilerplate appears in 3+ handlers.

**Scan:** This requires comparing handler code across files. Skip unless remaining turn budget.

**Manual check approach (if budget allows):**
1. Look for repeated patterns like logging, validation, or authorization checks at the top of handlers
2. Read 3-4 handlers from the same feature folder and compare
- **Severity:** info

---

## BE-CQRS-007 — Create commands return Guid only

**What to check:** Create command handlers (`IRequest<T>` used for POST create endpoints) must return `Guid`, not a full DTO. Flag `IRequest<SomeDto>` on create commands.

**Scan:**
```
Grep pattern: "record Create\w+Command.*IRequest<(?!Guid>|Unit>)"
     path:    backend/src/App.Application
     output_mode: content
```
- **True positive:** `record CreateEntityCommand(...) : IRequest<EntityDto>` — should return `Guid`
- **False positive:** `record CreateEntityCommand(...) : IRequest<Guid>` — correct
- **Confirm:** Read the file to verify the command is actually a create operation (not an update/action that happens to start with "Create" in the name).
- **Severity:** warning
