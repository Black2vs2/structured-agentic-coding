# Scan Playbook: Auth & Guards

Category: `auth` | Rules: BE-AUTH-001 through BE-AUTH-009

---

## BE-AUTH-001 — No manual @UseGuards() on resolvers

**What to check:** Global guard chain (UserAuthGuard → RolesGuard → PartnerAssignedGuard) is registered as `APP_GUARD`. Resolvers must not redeclare guards.

**Scan:**
```
Grep pattern: "@UseGuards\\("
     path:    __BE_DIR__/src/**/resolver
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
     path:    __BE_DIR__/src
     output_mode: content
```
Also:
```
Grep pattern: "jwt\\.(decode|verify)|jsonwebtoken"
     path:    __BE_DIR__/src
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
     path:    __BE_DIR__/src
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
        path:    __BE_DIR__/src
        output_mode: content
   ```
2. For each entity/DTO class containing one, grep for `logger.*(entity|user)` patterns:
   ```
   Grep pattern: "logger\\.(info|debug|warn|error)\\([^)]*\\b(user|entity)\\b"
        path:    __BE_DIR__/src
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
        path:    __BE_DIR__/src/**/resolver
        output_mode: content
        -A:      30
   ```
2. For each, read the method body. Flag if there's a `save()`, `update()`, or `delete()` before any role-derived branch.

- **True positive:** A mutation that calls `repo.save(...)` and then checks `if (!user.roles.includes(...)) throw`.
- **False positive:** Role check is in an interceptor / upstream guard — no inline check needed.
- **Confirm:** Read the method; if the guard chain (via `@RequiredRoles`) rejects BEFORE the method runs, the check is already fail-fast and OK.
- **Severity:** info (often the global chain covers it; escalate only if you find real post-side-effect checks)

---

## BE-AUTH-006 — @Authorize on all queryable DTOs

**What to check:** Every DTO used as the first type arg to a `CRUDResolver` with read enabled must declare `@Authorize` at the class level.

**Scan:**
```
Grep pattern: "^export class \\w+DTO"
     path:    __BE_DIR__/src/**/dto
     output_mode: content
```
For each DTO file, then:
```
Grep pattern: "@Authorize\\("
     path:    <same file>
     output_mode: content
```
If no match, cross-reference: is the DTO used in a `CRUDResolver(DTO, ...)`? If yes AND read is not disabled, this is a violation.

- **True positive:** `OrderDTO` used by `OrdersResolver extends CRUDResolver(OrderDTO, { ... })` with no `@Authorize` on the class.
- **False positive:** Nested DTOs returned only as part of a parent relation (they inherit the parent's filter). Must have a comment like `/** Nested DTO — authorization inherited from parent. */`. Public reference-data lookups that carry a `// Public lookup: <reason>` comment.
- **Confirm:** Read the resolver file for the DTO; if CRUDResolver has `read: { disabled: true }`, this rule is satisfied by the absence of read.
- **Severity:** error

---

## BE-AUTH-007 — Feature-level guards on partner-scoped resolvers

**What to check:** Resolvers whose DTO scopes by `partnerId`/`customerPartnerId` must apply `@UseGuards(PartnerAssignedGuard(...))` at the class level, OR be admin-only via class-level `@RequiredRoles(UserRole.PLATFORM_ADMIN)`.

**Scan:**
```
Grep pattern: "^@Resolver\\(\\(\\)\\s*=>\\s*\\w+DTO\\)"
     path:    __BE_DIR__/src/**/resolver
     output_mode: content
     -A:      2
```
For each resolver class, check the next 2 lines for one of:
- `@UseGuards(PartnerAssignedGuard(`
- `@RequiredRoles(UserRole.PLATFORM_ADMIN`

If neither is present, open the DTO file and check whether its `@Authorize` fallback references `partnerId` / `customerPartnerId`. If yes, this is a violation.

- **True positive:** `ProductResolver` extending CRUDResolver over `ProductDTO` (which has `@Authorize` with a `partnerId` fallback), but no class-level `PartnerAssignedGuard` and not `PLATFORM_ADMIN`-only.
- **False positive:** Resolver has per-method guards explicitly (rare — prefer class-level). Public lookup resolvers with no partner scoping.
- **Confirm:** Read the DTO's `@Authorize` block to confirm partner scoping before flagging.
- **Severity:** error

---

## BE-AUTH-008 — Custom mutations take @LoggedUser and delegate scoping

**What to check:** Every custom `@Mutation` on a CRUDResolver subclass must either (a) accept `@LoggedUser() user: UserEntity` and pass it to a service that enforces scoping, or (b) be class-level `@RequiredRoles(UserRole.PLATFORM_ADMIN)`.

**Scan:**
```
Grep pattern: "@Mutation\\("
     path:    __BE_DIR__/src/**/resolver
     output_mode: content
     -A:      10
```
For each match that is NOT inside a class annotated `@RequiredRoles(UserRole.PLATFORM_ADMIN)`:
- Look for `@LoggedUser()` in the arg list (the next ~5 lines).
- If absent, read the method body — if it performs any DB write on partner-scoped data without passing `user` or its `partnerId` into the service call, flag it.

- **True positive:** `async confirmOrder(@Args('input') input: OrderIdInput) { return this.orderService.confirm(input.id); }` — no user, no scope check.
- **False positive:** The resolver class has `@RequiredRoles(PLATFORM_ADMIN)` — admin-only mutations don't need scoping.
- **Confirm:** Read the service method called — does it enforce `partnerId` scoping from the user, or does it trust the id? Trust-the-id is the bug.
- **Severity:** warning

---

## BE-AUTH-009 — requestFilterKey pattern documented

**What to check:** Any `@Authorize` block using `requestFilterKey: <SYMBOL>` must have a JSDoc comment above it naming the guard that populates the key.

**Scan:**
```
Grep pattern: "requestFilterKey\\s*:"
     path:    __BE_DIR__/src/**/dto
     output_mode: content
     -B:      5
```
For each match, read the 5 lines above the `@Authorize`. Flag if there is no comment naming the guard.

- **True positive:** `@Authorize({ requestFilterKey: OUTBOUND_FILTER_KEY })` with no JSDoc above.
- **False positive:** A comment like `/** Filter key set by OutboundAuthGuard in src/outbounds/outbound-auth.guard.ts. */` is present.
- **Confirm:** The guard named in the JSDoc actually exists and sets the key (spot-check).
- **Severity:** warning
