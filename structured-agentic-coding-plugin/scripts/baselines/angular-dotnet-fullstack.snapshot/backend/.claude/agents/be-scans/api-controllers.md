# Scan Playbook: API & Controllers

Category: `api-controllers` | Rules: BE-API-001 through BE-API-006

---

## BE-API-001 — Thin controllers

**What to check:** Controller actions should only contain `mediator.Send()` (or `_mediator.Send()`). Flag any business logic, database access, service calls, or complex mapping inside controller methods.

**Scan 1 — Find non-mediator operations in controllers:**
```
Grep pattern: "(DbContext|_db\.|\.SaveChanges|\.ToList|\.FirstOrDefault|\.Where\(|\.Select\()"
     path:    backend/src/App.Api/Controllers
     output_mode: content
```
- **True positive:** `var result = _db.Entities.Where(...).ToListAsync();` in a controller — DB access should be in a handler
- **False positive:** None — controllers should never access DB directly
- **Confirm:** No confirmation needed.
- **Severity:** warning

**Scan 2 — Find service calls in controllers:**
```
Grep pattern: "(_emailService|_gitHub|_evaluationService|HttpClient)"
     path:    backend/src/App.Api/Controllers
     output_mode: content
```
- **True positive:** `await _emailService.Send(...)` in a controller action
- **False positive:** None — all service calls should go through handlers
- **Confirm:** No confirmation needed. Exception: `_mediator` calls are expected.
- **Severity:** warning

**Scan 3 — Verify mediator-only pattern:**
```
Grep pattern: "public async"
     path:    backend/src/App.Api/Controllers
     output_mode: content
     context: 5
```
- **Interpretation:** For each controller action, the body should essentially be: validate route params -> create command/query -> `mediator.Send()` -> return result. Multiple statements beyond this pattern are suspicious.
- **Priority:** Only spot-check 2-3 controllers if budget allows. The targeted scans above should catch the obvious cases.

---

## BE-API-002 — Consistent HTTP status codes

**What to check:** POST create -> 201 (CreatedAtAction). PUT/PATCH -> 200 (Ok). DELETE -> 204 (NoContent).

**Scan 1 — POST actions returning 200 instead of 201:**
```
Grep pattern: "\[HttpPost\]"
     path:    backend/src/App.Api/Controllers
     output_mode: content
     context: 8
```
- **Interpretation:** For each `[HttpPost]` action, check if it returns `Ok(...)` when it should return `CreatedAtAction(...)` or `Created(...)`. POST that creates a resource should return 201.
- **True positive:** `[HttpPost] ... return Ok(id);` for a create endpoint
- **False positive:** `[HttpPost("revoke")]` or `[HttpPost("mark-sent")]` — these are action endpoints, not creates. `Ok()` is correct.
- **Confirm:** Read the action to determine if it's a creation (returns a new Id) or an action (invokes behavior on existing resource).
- **Severity:** warning

**Scan 2 — DELETE actions not returning NoContent:**
```
Grep pattern: "\[HttpDelete\]"
     path:    backend/src/App.Api/Controllers
     output_mode: content
     context: 5
```
- **True positive:** `[HttpDelete("{id}")] ... return Ok();` — should be `NoContent()`
- **False positive:** None
- **Severity:** info

---

## BE-API-003 — Route naming conventions

**What to check:** Routes must use lowercase kebab-case plural nouns. Flag uppercase, camelCase, underscores, or singular nouns in routes.

**Scan:**
```
Grep pattern: "\[Http(Get|Post|Put|Delete|Patch)\(\"[^\"]*[A-Z_][^\"]*\"\)"
     path:    backend/src/App.Api/Controllers
     output_mode: content
```
- **True positive:** `[HttpGet("getUserById")]` — camelCase route
- **True positive:** `[HttpGet("user_stories")]` — underscores
- **False positive:** `[HttpGet("{id}")]` — route parameter with lowercase, correct
- **False positive:** `[HttpGet("{id:guid}")]` — route constraint, correct
- **Confirm:** Check if uppercase characters are inside `{...}` route parameters (acceptable) or in static segments (violation).
- **Severity:** info

Also check controller-level `[Route]` attributes:
```
Grep pattern: "\[Route\(\"api/[^\"]*\"\)\]"
     path:    backend/src/App.Api/Controllers
     output_mode: content
```
- **True positive:** `[Route("api/userStories")]` — camelCase
- **False positive:** `[Route("api/candidates")]` — correct

---

## BE-API-004 — AllowAnonymous requires comment

**What to check:** Any `[AllowAnonymous]` attribute must have a justification comment explaining why the endpoint is public.

**Scan:**
```
Grep pattern: "\[AllowAnonymous\]"
     path:    backend/src/App.Api
     output_mode: content
     context: 2
     -B:      2
```
- **True positive:** `[AllowAnonymous]` with no `//` comment on the line above or same line
- **False positive:** `[AllowAnonymous] // Public: candidate portal, no OAuth required` — has justification
- **Confirm:** Check the 2 lines before the attribute and the attribute line itself for a `//` comment. If no comment exists, it's a violation.
- **Severity:** warning

---

## BE-API-005 — OpenAPI auto-generation sufficient

**What to check:** Do NOT flag missing `[ProducesResponseType]` attributes. Flag untyped `IActionResult` return types when a typed return (e.g., `ActionResult<MyDto>`) would improve the OpenAPI spec.

**Scan:**
```
Grep pattern: "public async Task<IActionResult>"
     path:    backend/src/App.Api/Controllers
     output_mode: content
```
- **True positive:** `public async Task<IActionResult> GetById(...)` — should be `Task<ActionResult<MyDto>>` for better spec
- **False positive:** `public async Task<IActionResult> Delete(...)` — returns no body, IActionResult is acceptable
- **Confirm:** Read the action to check if it returns a body (`Ok(result)`) or not (`NoContent()`). If it returns a body, suggest typed return.
- **Severity:** info

---

## BE-API-006 — No API versioning

**What to check:** Flag `/v1/`, `/v2/`, `api-version` prefixes in routes.

**Scan:**
```
Grep pattern: "/v\d+/|api-version|ApiVersion"
     path:    backend/src/App.Api
     output_mode: content
```
- **True positive:** `[Route("api/v1/entities")]` — versioned route
- **False positive:** None
- **Confirm:** No confirmation needed.
- **Severity:** warning
