# Scan Playbook: API & Data

Category: `api` | Rules: FE-API-001 through FE-API-005

---

## FE-API-001 -- Generated API services only

**What to check:** API imports must come from `@libs/core/api`, not relative paths. No direct HttpClient.

**Scan 1 -- Relative imports of API-like services:**

```
Grep pattern: "from ['\"]\.\.?/.*\.(service|api)['\"]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `import { CandidatesApi } from '../../services/candidates.api'` — should use `from '@libs/core/api'`
- **False positive:** `import { UtilService } from '../util.service'` — non-API utility services can use relative imports
- **Confirm:** Check if the imported service is an API/HTTP service (should come from generated client) vs a utility service (relative import acceptable).
- **Severity:** warning

**Scan 2 -- Direct HttpClient usage (overlaps FE-STATE-005):**

```
Grep pattern: "HttpClient"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `inject(HttpClient)` or `private http: HttpClient` — should use generated services
- **False positive:** None — HttpClient should never be directly used
- **Confirm:** No confirmation needed. Any match is a violation.
- **Severity:** warning

Note: This scan overlaps with FE-STATE-005. Report under FE-API-001 to avoid duplicates if both flagged.

---

## FE-API-002 -- Error interceptor + store-level handling

**What to check:** Every rxMethod in stores has catchError + finalize. Critical flows have custom error messages.

**Note:** This rule's scan is identical to FE-STATE-004. The reviewer should deduplicate — run the FE-STATE-004 scan and report any missing catchError/finalize under FE-STATE-004 (not FE-API-002). FE-API-002 adds the additional requirement of custom error messages for critical flows (invites, evaluations), which requires contextual reading.

**Scan -- Custom error handling in critical flows:**

```
Grep pattern: "catchError"
     path:    frontend/libs/features/invites
     output_mode: content
     glob:    "*.store.ts"
     -C:      3
```

```
Grep pattern: "catchError"
     path:    frontend/libs/features/evaluations
     output_mode: content
     glob:    "*.store.ts"
     -C:      3
```

- **Interpretation:** For critical flows (invites, evaluations), the catchError block should include `MessageService.add()` with a translated error message, not just return EMPTY silently.
- **True positive:** `catchError(() => EMPTY)` in invite/evaluation store without any error notification
- **False positive:** `catchError((err) => { this.messageService.add({...}); return EMPTY; })` — has user notification
- **Confirm:** Read the catchError block in critical flow stores to verify user-facing error messages exist.
- **Severity:** info

---

## FE-API-003 -- OpenAPI drift detection (deep check)

**What to check:** When generated client files or API usage patterns appear in the diff, the reviewer should perform an OpenAPI drift deep check (this was previously a separate specialist agent, now absorbed into the Code Reviewer).

**Trigger condition:**

- Generated client files (`frontend/libs/core/api/src/lib/generated/`) appear in the git diff
- New API service imports or method calls are added

**Action:** The Code Reviewer performs the drift check directly as a Tier 2 deep check: glob generated services, read backend controllers, cross-reference for missing/extra endpoints.

No Grep scan needed for this rule — it triggers the deep check procedure in the Code Reviewer.

---

## FE-API-004 -- No barrel import bloat

**What to check:** Flag imports from library root when deep import is available. PrimeNG must use deep imports (`primeng/button`, not `primeng`).

**Scan 1 -- PrimeNG root imports:**

```
Grep pattern: "from ['\"]primeng['\"]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `import { ButtonModule } from 'primeng'` — should be `import { ButtonModule } from 'primeng/button'`
- **False positive:** `import { ButtonModule } from 'primeng/button'` — deep import, correct (not matched by this pattern)
- **Confirm:** No confirmation needed. Any root `primeng` import is a violation.
- **Severity:** warning

**Scan 2 -- Angular root imports (if applicable):**

```
Grep pattern: "from ['\"]@angular/(material|cdk)['\"]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `import { ScrollingModule } from '@angular/cdk'` — should be `from '@angular/cdk/scrolling'`
- **False positive:** `import { ScrollingModule } from '@angular/cdk/scrolling'` — deep import, correct (not matched)
- **Confirm:** No confirmation needed. Any root Angular material/cdk import is a violation.
- **Severity:** warning

Note: This scan overlaps with FE-UI-001 and FE-STYLE-003. The reviewer should deduplicate — report under FE-API-004.

---

## FE-API-005 -- No business/UI logic in libs/core/api

**What to check:** Flag any hand-written file in `libs/core/api/src/lib/` that is NOT inside the `generated/` directory. The `@libs/core/api` library must contain only generated code and the barrel `index.ts`.

**Scan 1 -- Non-generated files in core/api:**

```
Glob pattern: "libs/core/api/src/lib/*.ts"
      path:   frontend
```

- **Interpretation:** Any `.ts` file directly in `libs/core/api/src/lib/` (not inside `generated/`) is a violation. Only the `generated/` directory should exist here.
- **True positive:** `libs/core/api/src/lib/enums.ts`, `libs/core/api/src/lib/status-severity.ts` — hand-written logic in generated-only zone
- **False positive:** Files inside `libs/core/api/src/lib/generated/` — these are auto-generated and correct
- **Confirm:** Check if the file is inside `generated/`. If not, it's a violation.
- **Severity:** error

**Scan 2 -- Pipe/decorator classes in core/api:**

```
Grep pattern: "@Pipe|@Component|@Directive|@Injectable"
     path:    frontend/libs/core/api/src
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** Any Angular decorator in `libs/core/api/src/` — UI/DI logic does not belong here
- **False positive:** None — generated code does not contain Angular decorators
- **Confirm:** No confirmation needed. Any match is a violation.
- **Severity:** error

### Where to move violations

| Type                       | Move to                                          |
| -------------------------- | ------------------------------------------------ |
| Pipes                      | `@libs/ui/{pipe-name}` (own lib per FE-COMP-007) |
| Enum config / enum helpers | `@libs/ui/enum-pipes`                            |
| Severity mappers           | `@libs/ui/status-severity-pipe`                  |
| Domain utility functions   | `@libs/core/{domain}`                            |
