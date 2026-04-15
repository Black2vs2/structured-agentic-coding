# Scan Playbook: Architecture & Structure

Category: `architecture` | Rules: BE-ARCH-001 through BE-ARCH-005

---

## BE-ARCH-001 — 4-layer dependency direction

**What to check:** Dependencies must flow inward: Api -> Migrations -> Application -> Domain. Any reverse import is a violation.

**Scan 1 — Domain importing Application or higher:**
```
Grep pattern: "using App\.(Application|Migrations|Api)"
     path:    backend/src/App.Domain
     output_mode: content
```
- **True positive:** `using App.Application.Something;` in any Domain file
- **False positive:** None — Domain should NEVER reference other layers
- **Confirm:** No confirmation needed. Any match is a violation.
- **Severity:** warning

**Scan 2 — Application importing Api or Migrations:**
```
Grep pattern: "using App\.(Api|Migrations)"
     path:    backend/src/App.Application
     output_mode: content
```
- **True positive:** `using App.Api.Controllers;` in a handler file
- **False positive:** None — Application should never reference Api or Migrations
- **Confirm:** No confirmation needed. Any match is a violation.
- **Severity:** warning

**Scan 3 — Migrations importing Api:**
```
Grep pattern: "using App\.Api"
     path:    backend/src/App.Migrations
     output_mode: content
```
- **True positive:** `using App.Api.Auth;` in a configuration file
- **False positive:** None
- **Confirm:** No confirmation needed.
- **Severity:** warning

---

## BE-ARCH-002 — Feature-based CQRS folders

**What to check:** Application layer must use `{Feature}/Commands/` and `{Feature}/Queries/` structure. Files placed outside this convention are violations.

**Scan:**
```
Grep pattern: "class \w+Handler.*IRequestHandler"
     path:    backend/src/App.Application
     output_mode: content
```
- **True positive:** A handler class in a file NOT inside a `Commands/` or `Queries/` subfolder (check the file path in the match)
- **False positive:** Handlers correctly placed in `{Feature}/Commands/{HandlerName}.cs` — this is correct
- **Confirm:** Check the file path of each match. If the path doesn't follow `{Feature}/Commands/` or `{Feature}/Queries/` pattern, it's a violation.
- **Severity:** info

---

## BE-ARCH-003 — Co-locate command+handler+DTO

**What to check:** Each `IRequest<T>` record and its `IRequestHandler` implementation must live in the same file. Shared DTOs go in a `DTOs/` subfolder.

**Scan:**
```
Grep pattern: "IRequestHandler<(\w+)"
     path:    backend/src/App.Application
     output_mode: content
```
- **Interpretation:** Extract the request type name from matches. Then grep for the request type definition. If the request record and handler are in different files, that's a violation.
- **Confirm:** Only investigate if you notice a handler referencing a request type that doesn't appear in the same file path. Read the file to verify both `record` and `class Handler` are present.
- **Severity:** info

---

## BE-ARCH-004 — Shared helpers in feature files

**What to check:** Flag code duplication >10 lines across handlers in the same feature. Do NOT flag small duplications.

**Scan:** This rule requires reading handler files within the same feature folder and comparing them. It cannot be reliably detected via Grep alone.

**Approach:**
1. Skip this rule during Grep scanning phase
2. Only check manually if you have remaining turn budget after all other scans
3. If checking: pick the largest feature folder and read 2-3 handlers to look for repeated patterns
- **Severity:** info

---

## BE-ARCH-005 — Direct DbContext in handlers accepted

**What to check:** Do NOT flag `AppDbContext` injection in handlers. Instead, flag any introduction of a generic repository pattern (e.g., `IRepository<T>`, `IGenericRepository`).

**Scan:**
```
Grep pattern: "IRepository<|IGenericRepository|IBaseRepository"
     path:    backend/src
     output_mode: content
```
- **True positive:** `class Handler(IRepository<Entity> repo)` — generic repository being used
- **False positive:** None — this project uses direct DbContext
- **Confirm:** No confirmation needed.
- **Severity:** warning
