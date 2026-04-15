# Scan Playbook: Testing

Category: `testing` | Rules: FE-TEST-001 through FE-TEST-004

> **Note:** Test-presence rules in this playbook ship at severity `info` until the project-wide Vitest + RTL harness is installed. Raise to `warning` once `bun run test` is part of the CI pipeline.

---

## FE-TEST-001 — .test.ts/.test.tsx naming

**What to check:** Vitest convention is `.test.ts` / `.test.tsx` (not `.spec`). Flag `.spec.*` files in `src/`.

**Scan:**
```
Glob pattern: ./src/**/*.spec.ts
Glob pattern: ./src/**/*.spec.tsx
```

- **True positive:** Any `.spec.ts` / `.spec.tsx` in `src/`. That's Jest/backend convention.
- **False positive:** E2E tests under `e2e/` using `.spec.ts` (Playwright convention) — allowed outside `src/`.
- **Confirm:** Path matters: `.spec.*` outside `src/` is OK (e2e); inside `src/` is wrong.
- **Severity:** warning (once harness installed)

---

## FE-TEST-002 — React Testing Library patterns

**What to check:** Component tests use accessibility-first queries from RTL.

**Scan:**
```
Grep pattern: "container\\.querySelector|document\\.querySelector"
     path:    ./src
     output_mode: content
```
Also:
```
Grep pattern: "getByTestId"
     path:    ./src
     output_mode: content
```
`getByTestId` is a fallback and OK sparingly, but overuse suggests accessibility gaps.

- **True positive:** Test using `container.querySelector('.my-class')` to find an element.
- **False positive:** Rare `getByTestId` with a justification comment (e.g., visually-identical siblings).
- **Confirm:** Check if a role-based query would work; if yes, rewrite.
- **Severity:** info

---

## FE-TEST-003 — MSW for GraphQL mocks

**What to check:** Tests mock GraphQL at the network layer via MSW, not at the client layer.

**Scan:**
```
Grep pattern: "jest\\.mock\\(['\"]@refinedev/nestjs-query"
     path:    ./src
     output_mode: content
```
Also:
```
Grep pattern: "vi\\.mock\\(['\"]@refinedev/nestjs-query"
     path:    ./src
     output_mode: content
```
Also check that MSW is actually imported:
```
Grep pattern: "from\\s+['\"]msw"
     path:    ./src
     output_mode: content
```

- **True positive:** Test mocks `@refinedev/nestjs-query` directly via `vi.mock`.
- **False positive:** Rare cases where MSW can't simulate a behavior (subscriptions over ws) — justify with a comment.
- **Confirm:** Check whether MSW is installed and used; if not, test-level client mocks are the fallback until MSW is added.
- **Severity:** warning (once harness installed)

---

## FE-TEST-004 — Coverage floor on changed lines

**What to check:** Changed lines in a PR should have >= 60% test coverage.

**Scan:** Requires coverage report.

**Approach:**
1. Run `bun run test --coverage` (when harness is available).
2. Parse `coverage/coverage-summary.json`.
3. For each file in `git diff --name-only origin/main`, check statement coverage.
4. Flag files below 60%.

- **True positive:** New resource page at 15% coverage.
- **False positive:** Files that are pure type declarations (`types.ts`) — excluded from coverage targets.
- **Confirm:** Check file type; pure types, generated files, and config are exempt.
- **Severity:** info (until harness installed)
