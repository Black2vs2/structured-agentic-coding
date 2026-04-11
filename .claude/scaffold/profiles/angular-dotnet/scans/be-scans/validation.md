# Scan Playbook: Validation & Error Handling

Category: `validation` | Rules: BE-VAL-001 through BE-VAL-006

---

## BE-VAL-001 — Fail-fast validation at top

**What to check:** All validation must come before any mutation or side effect. Flag handlers where validation checks appear AFTER database writes or external service calls.

**Scan:** This rule requires reading handler code flow. It cannot be detected by Grep pattern alone.

**Manual check approach (if budget allows):**
1. Pick 3-4 command handlers (particularly complex ones)
2. Read the `Handle` method
3. Check that validation (`throw new ValidationException`, null checks, business rule checks) appears BEFORE `SaveChangesAsync`, email sends, or external API calls
- **True positive:** A handler that calls `db.SaveChangesAsync()` halfway through, then does a validation check after
- **False positive:** A handler that validates, then saves — correct order
- **Severity:** warning
- **Priority:** Low — only check if remaining turn budget

---

## BE-VAL-002 — ApiException hierarchy only

**What to check:** Business errors must use the `ApiException` hierarchy (`NotFoundException`, `ValidationException`, `ConflictException`, `ForbiddenException`). Flag `throw new Exception(...)`, `throw new InvalidOperationException(...)`, `throw new ArgumentException(...)`.

**Scan:**
```
Grep pattern: "throw new (Exception|InvalidOperationException|ArgumentException|ArgumentNullException|NotImplementedException|NotSupportedException)\("
     path:    backend/src
     output_mode: content
```
- **True positive:** `throw new InvalidOperationException("Cannot complete expired entity");` — should use `throw new ConflictException("...")`
- **False positive:** `throw new ArgumentNullException(nameof(param))` in infrastructure code that validates internal method parameters (not business errors). These are acceptable in framework-level code but not in handlers.
- **Confirm:** Check the file path:
  - In `Application/` handlers: any non-ApiException throw is a violation
  - In `Domain/` entities: any non-ApiException throw is a violation
  - In `Api/` middleware/infrastructure: `ArgumentNullException` for parameter guards may be acceptable
- **Severity:** warning

---

## BE-VAL-003 — ProblemDetails format

**What to check:** Flag hardcoded English error messages in exception constructors. New exceptions must extend `ApiException`.

**Scan 1 — Find exception classes:**
```
Grep pattern: "class \w+Exception\s*:"
     path:    backend/src/__BE_NAMESPACE__.Domain
     output_mode: content
```
- **Interpretation:** All exception classes must inherit from `ApiException` (directly or indirectly).
- **True positive:** `class MyCustomException : Exception` — doesn't extend ApiException
- **False positive:** `class NotFoundException : ApiException` — correct

**Scan 2 — Hardcoded strings in throws:**
This overlaps with BE-VAL-002 results. When reviewing those matches, also note if the error message is hardcoded English that should be an i18n key. For most projects, hardcoded English is currently the norm, so only flag as info severity.
- **Severity:** info

---

## BE-VAL-004 — Null handling on entity lookups

**What to check:** Flag `FirstOrDefaultAsync`/`SingleOrDefaultAsync` without a subsequent null check. The pattern should be `?? throw new NotFoundException(...)`.

**Scan:**
```
Grep pattern: "(FirstOrDefaultAsync|SingleOrDefaultAsync)\("
     path:    backend/src/__BE_NAMESPACE__.Application
     output_mode: content
```
- **True positive:** `var entity = await db.Entities.FirstOrDefaultAsync(c => c.Id == id);` followed by usage of `entity` without null check
- **False positive:** `var entity = await db.Entities.FirstOrDefaultAsync(...) ?? throw new NotFoundException(...)` — correct pattern
- **Confirm:** Read surrounding lines for each match. Look for `?? throw new NotFoundException` on the same line or `if (entity is null) throw` on the next line. If neither exists, it's a violation.
- **Severity:** warning

**Also scan for SingleAsync which should be FirstOrDefaultAsync + null check:**
```
Grep pattern: "SingleAsync\("
     path:    backend/src/__BE_NAMESPACE__.Application
     output_mode: content
```
- **True positive:** `await db.Entities.SingleAsync(c => c.Id == id)` — throws generic exception on not-found, should use `FirstOrDefaultAsync ?? throw new NotFoundException`
- **False positive:** None — SingleAsync should generally be replaced
- **Severity:** info

---

## BE-VAL-005 — No swallowed exceptions

**What to check:** Flag empty `catch` blocks. Flag `catch` blocks without rethrow, logging, or exception conversion.

**Scan:**
```
Grep pattern: "catch\s*(\(\w+(\s+\w+)?\))?\s*\{"
     path:    backend/src
     output_mode: content
     context: 3
```
- **True positive:** `catch (Exception) { }` — empty catch, swallowing exception
- **True positive:** `catch (Exception ex) { // do nothing }` — swallowed
- **False positive:** `catch (Exception ex) { _logger.LogError(ex, "..."); throw; }` — correct: logs and rethrows
- **False positive:** `catch (HttpRequestException ex) { throw new ApiException("Service unavailable", ex); }` — correct: converts to domain exception
- **Confirm:** The context=3 from Grep should show the catch body. If the body is empty, contains only a comment, or doesn't log/rethrow/convert, it's a violation.
- **Severity:** warning

---

## BE-VAL-006 — Log external service failures

**What to check:** Catch blocks around HTTP/SMTP/external service calls must log at Warning or Error level.

**Scan:**
```
Grep pattern: "catch.*(HttpRequestException|SmtpException|HttpClient)"
     path:    backend/src
     output_mode: content
     context: 5
```
- **True positive:** Catching an HTTP exception without any `_logger.Log` call in the catch body
- **False positive:** Catch block that includes `_logger.LogWarning(...)` or `_logger.LogError(...)` — correct
- **Confirm:** Check the catch body (from context lines) for any `Log(Warning|Error)` call. If absent, it's a violation.
- **Severity:** warning

If scan 1 has no results, also try:
```
Grep pattern: "catch.*Exception.*\{[^}]*\}"
     path:    backend/src/__BE_NAMESPACE__.Application
     output_mode: content
     multiline: true
```
Then manually check if any of those catches are around external service calls (check the try block).
