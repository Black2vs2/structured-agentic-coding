# Scan Playbook: Testing

Category: `testing` | Rules: BE-TEST-001 through BE-TEST-004

> **Note:** Test-presence rules in this playbook ship at severity `info` until the project-wide Jest harness is installed. Raise to `warning` once `bun run test` is part of the CI pipeline.

---

## BE-TEST-001 — *.spec.ts naming convention

**What to check:** Unit tests co-locate with source and use the `.spec.ts` suffix. `test/` directory is for e2e.

**Scan:**
```
Glob pattern: ./src/**/*.test.ts
```
Any match is a violation — should be renamed to `.spec.ts`.

Also:
```
Glob pattern: ./src/**/*.spec.ts
```
List sources. For feature modules, verify there's at least one spec file (service/resolver/guard). If zero specs for a feature, flag.

- **True positive:** `foo.service.test.ts` instead of `foo.service.spec.ts`; feature module with zero spec files.
- **False positive:** Features intentionally without tests yet (e.g., brand-new module). Gets severity `info` until harness installed.
- **Confirm:** Check Jest config (`jest` block in package.json) for the `testRegex` — must match `.spec.ts`.
- **Severity:** info (until harness installed; then warning)

---

## BE-TEST-002 — Mock Repository via getRepositoryToken

**What to check:** Service tests inject a mocked Repository via `{ provide: getRepositoryToken(Entity), useValue: {...} }`.

**Scan:**
```
Grep pattern: "getRepository(?!Token)"
     path:    ./src/**/*.spec.ts
     output_mode: content
```
Also:
```
Grep pattern: "import.*DataSource.*from ['\"]typeorm['\"]"
     path:    ./src/**/*.spec.ts
     output_mode: content
```

- **True positive:** `dataSource.getRepository(Entity)` in a spec — that hits a real connection (or fails at runtime).
- **False positive:** Integration tests under `test/` (not `*.spec.ts`) legitimately use real repositories.
- **Confirm:** Read the spec; `getRepositoryToken` + `useValue` is the expected pattern.
- **Severity:** warning (once harness installed)

---

## BE-TEST-003 — AAA structure

**What to check:** Test bodies should be organized Arrange / Act / Assert (comments or blank lines separating).

**Scan:** Hard to detect programmatically — rely on review.

**Approach:**
1. Read a sample of spec files (2-3 per feature).
2. For each `it(...)` block, check if mocking/setup is clearly separated from the action under test and the assertion.
3. Flag blocks where a single line mixes all three (e.g., `expect(await service.foo(mockRepo.find.mockResolvedValue(x))).toBe(y)`).

- **True positive:** Interleaved setup/action/assertion making intent unclear.
- **False positive:** Simple one-assertion tests with inline setup — OK for trivial cases.
- **Confirm:** Subjective — only flag egregious cases.
- **Severity:** info

---

## BE-TEST-004 — Coverage floor on changed lines

**What to check:** Changed lines in a PR should have >= 60% test coverage.

**Scan:** Requires coverage report. Run:
```
Bash: bun run test --coverage --coverageReporters=json-summary
```
Then read `coverage/coverage-summary.json` and compare against git diff ranges.

**Approach:**
1. Run tests with coverage.
2. Parse `coverage-summary.json`.
3. For each changed file (via `git diff --name-only origin/main`), check the statement coverage.
4. Flag files below 60%.

- **True positive:** Changed service file at 20% coverage.
- **False positive:** Files that are pure type definitions (0 coverage is fine — nothing to cover).
- **Confirm:** Check the file type; pure `*.dto.ts` / `*.entity.ts` / `*.types.ts` are excluded.
- **Severity:** info (until harness installed; then warning)
