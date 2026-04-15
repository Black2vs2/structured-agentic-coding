# Scan Playbook: Auth & Guards

Category: `auth` | Rules: BE-AUTH-001 through BE-AUTH-005

---

## BE-AUTH-001 — No manual @UseGuards() on resolvers

**What to check:** Global guard chain (UserAuthGuard → RolesGuard → PartnerAssignedGuard) is registered as `APP_GUARD`. Resolvers must not redeclare guards.

**Scan:**
```
Grep pattern: "@UseGuards\\("
     path:    ./src/**/resolver
     output_mode: content
```

- **True positive:** `@UseGuards(UserAuthGuard)` on a `@Resolver()` class or `@Query/@Mutation` method.
- **False positive:** `@UseGuards` on a REST `@Controller` (non-GraphQL) may be acceptable if the controller runs a public endpoint that opts into specific guards — read and assess.
- **Confirm:** If the file has `@Resolver` at the top, any `@UseGuards` in the file is a violation.
- **Severity:** error

---

## BE-AUTH-002 — Firebase token verify not bypassed

**What to check:** Nobody reads `authorization` header directly or decodes JWTs ad-hoc; only `UserAuthGuard` via `FirebaseService.verifyIdToken` is allowed.

**Scan:**
```
Grep pattern: "req\\.headers\\.authorization|request\\.headers\\.authorization"
     path:    ./src
     output_mode: content
```
Also:
```
Grep pattern: "jwt\\.(decode|verify)|jsonwebtoken"
     path:    ./src
     output_mode: content
```

- **True positive:** `const token = req.headers.authorization?.split(' ')[1]` in a resolver or service.
- **False positive:** The implementation inside `UserAuthGuard` itself reads the header — that's the ONE allowed place.
- **Confirm:** Read file; if it's `user-auth.guard.ts` or similar, it's the allowed implementation.
- **Severity:** error

---

## BE-AUTH-003 — @PartnerNotRequired needs justification

**What to check:** Uses of `@PartnerNotRequired()` must have a comment explaining why.

**Scan:**
```
Grep pattern: "@PartnerNotRequired\\(\\)"
     path:    ./src
     output_mode: content
     -B:      3
```

- **True positive:** `@PartnerNotRequired()` with no preceding `//` comment.
- **False positive:** A preceding JSDoc or `//` comment in the 1-3 lines above explaining the intent.
- **Confirm:** Read the lines above the decorator.
- **Severity:** warning

---

## BE-AUTH-004 — @AdminOnlyField fields not logged

**What to check:** Logging calls must not serialize an object containing @AdminOnlyField data.

**Scan:** This requires cross-file inspection: first identify @AdminOnlyField annotated fields, then grep for logger calls that pass the containing entity.

**Approach:**
1. List all @AdminOnlyField occurrences:
   ```
   Grep pattern: "@AdminOnlyField\\(\\)"
        path:    ./src
        output_mode: content
   ```
2. For each entity/DTO class containing one, grep for `logger.*(entity|user)` patterns:
   ```
   Grep pattern: "logger\\.(info|debug|warn|error)\\([^)]*\\b(user|entity)\\b"
        path:    ./src
        output_mode: content
   ```
3. Manually verify whether the logged object carries admin-only fields.

- **True positive:** `logger.info('user updated', { user })` where `user` has an @AdminOnlyField.
- **False positive:** Logging only a few specific safe fields (e.g., `logger.info('user id', { id: user.id })`).
- **Confirm:** Inspect the log payload; if it contains the full object, assume all fields leak.
- **Severity:** warning

---

## BE-AUTH-005 — Role check precedes business logic

**What to check:** Role-gated mutations should short-circuit before any DB writes.

**Scan:** Structural — requires reading handlers.

**Approach:**
1. Find mutations with `@RequiredRoles`:
   ```
   Grep pattern: "@RequiredRoles\\("
        path:    ./src/**/resolver
        output_mode: content
        -A:      30
   ```
2. For each, read the method body. Flag if there's a `save()`, `update()`, or `delete()` before any role-derived branch.

- **True positive:** A mutation that calls `repo.save(...)` and then checks `if (!user.roles.includes(...)) throw`.
- **False positive:** Role check is in an interceptor / upstream guard — no inline check needed.
- **Confirm:** Read the method; if the guard chain (via `@RequiredRoles`) rejects BEFORE the method runs, the check is already fail-fast and OK.
- **Severity:** info (often the global chain covers it; escalate only if you find real post-side-effect checks)
