# Scan Playbook: UI Patterns

Category: `ui-patterns` | Rules: FE-UI-001 through FE-UI-009

---

## FE-UI-001 -- PrimeNG tree-shake imports

**What to check:** Flag root PrimeNG imports. Must use deep imports like `primeng/button`, `primeng/table`.

**Scan:**

```
Grep pattern: "from ['\"]primeng['\"]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `import { ButtonModule } from 'primeng'` — should be `from 'primeng/button'`
- **False positive:** `import { ButtonModule } from 'primeng/button'` — correct deep import (not matched)
- **Confirm:** No confirmation needed. Any root import is a violation.
- **Severity:** warning

Note: Overlaps with FE-API-004. The reviewer should deduplicate — report under FE-API-004.

---

## FE-UI-002 -- Lazy load heavy PrimeNG components

**What to check:** Flag heavy PrimeNG components (Dialog, Editor, Calendar, FileUpload) imported in eagerly loaded components (those referenced directly in route configs without `loadComponent`).

**Scan 1 -- Find heavy PrimeNG imports:**

```
Grep pattern: "from ['\"]primeng/(dialog|editor|calendar|fileupload|datepicker)['\"]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

**Scan 2 -- Cross-reference with eagerly loaded components:**

```
Grep pattern: "\bcomponent\s*:"
     path:    frontend/libs
     output_mode: content
     glob:    "*.routes.ts"
```

- **Interpretation:** If a component is eagerly loaded (uses `component:` instead of `loadComponent:` in routes) AND imports heavy PrimeNG modules, it bloats the initial bundle.
- **True positive:** A component loaded via `component: DashboardComponent` that imports `EditorModule` from PrimeNG
- **False positive:** Same import in a lazily loaded component (via `loadComponent`) — lazy loading is fine
- **Confirm:** Trace the component to its route definition to determine if it's eagerly or lazily loaded.
- **Severity:** info

---

## FE-UI-003 -- DynamicDialog for all modals

**What to check:** Flag `<p-dialog>` usage in templates. All modals should use `DialogService.open()` with standalone dialog components.

**Scan:**

```
Grep pattern: "<p-dialog"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `<p-dialog header="Edit" [(visible)]="showDialog">` — should use DynamicDialog
- **False positive:** None — `<p-dialog>` should not appear in templates
- **Confirm:** No confirmation needed. Any `<p-dialog>` in a template is a violation.
- **Severity:** warning

---

## FE-UI-004 -- Detail page save in page header

**What to check:** Save button should be in `<ui-page-header>`, not inside the form component. The page uses `viewChild` to call `form.onSave()`.

**Scan 1 -- Find save buttons in form templates:**

```
Grep pattern: "(click)=\".*save|type=\"submit\""
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

**Scan 2 -- Find ui-page-header with action buttons:**

```
Grep pattern: "ui-page-header"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
     -C:      5
```

- **Interpretation:** Save/submit buttons should be in the page component's template (inside `<ui-page-header>` right slot), not inside the form component's template.
- **True positive:** `<button (click)="save()">Save</button>` inside a form component template
- **False positive:** Same button inside a page component's `<ui-page-header>` right slot
- **Confirm:** Read the file path and template structure to determine if the save button is in a form component (violation) vs a page component (correct).
- **Severity:** info

---

## FE-UI-005 -- Status chips via shared component

**What to check:** Flag inline status displays with hardcoded colors. Use the shared status chip component instead.

**Scan:**

```
Grep pattern: "style=\"color:|style=\"background-color:|\\[style\\.(color|backgroundColor)\\]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `<span style="color: green">Active</span>` near status text — should use shared chip
- **True positive:** `[style.backgroundColor]="getStatusColor(status)"` — should use shared chip component
- **False positive:** Styling unrelated to status display
- **Confirm:** Read the template context to determine if the inline style is for status display (violation) vs other styling (acceptable, but may violate FE-STYLE-001 instead).
- **Severity:** info

---

## FE-UI-006 -- All enum/status values handled

**What to check:** Compare generated API enum values against chip/badge color mappings. Flag unhandled values.

**Scan 1 -- Find status/enum mappings:**

```
Grep pattern: "(statusColor|chipColor|badgeColor|severityMap|colorMap)\s*[:=]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
     -C:      10
```

**Scan 2 -- Find enum definitions in generated code:**

```
Grep pattern: "export (enum|type)\s+\w*(Status|Type|Seniority)"
     path:    frontend/libs/core/api/src/lib/generated
     output_mode: content
     glob:    "*.ts"
```

- **Interpretation:** Cross-reference enum values from the generated API client with the status-to-color mappings. Unhandled enum values will produce broken/missing chips.
- **True positive:** Generated enum `InviteStatus` has `Draft | Sent | Started | Completed | Expired | Revoked` but chip mapping only handles `Draft | Sent | Completed`
- **False positive:** All enum values present in the mapping
- **Confirm:** Read both the enum definition and the color mapping to verify all values are handled.
- **Priority:** Medium — requires cross-referencing generated types with component mappings.
- **Severity:** warning

---

## FE-UI-007 -- Confirmation for destructive actions

**What to check:** Delete/revoke endpoints must show `ConfirmationService.confirm()` with translated message and entity name before executing.

**Scan 1 -- Find destructive operations:**

```
Grep pattern: "\.(delete|remove|revoke|archive)\w*\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.{ts,html}"
     -i:      true
```

**Scan 2 -- Find confirmation service usage:**

```
Grep pattern: "ConfirmationService|confirmationService|\.confirm\("
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.ts"
```

- **Interpretation:** For each destructive action, verify it's preceded by a confirmation dialog.
- **True positive:** `(click)="store.deleteCandidate(id)"` directly without confirmation dialog
- **False positive:** `(click)="confirmDelete(id)"` where `confirmDelete` calls `confirmationService.confirm()` first
- **Confirm:** Read the component/store code to verify the destructive action is wrapped in a confirmation flow.
- **Severity:** warning

---

## FE-UI-008 -- Loading, empty, and error states

**What to check:** Every `isLoading` signal needs a template loading indicator. Every list needs an empty state. Every fetch needs an error state.

**Scan 1 -- Find loading signals in stores:**

```
Grep pattern: "isLoading|loading\(\)"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.store.ts"
```

**Scan 2 -- Find loading indicators in templates:**

```
Grep pattern: "isLoading|loading\(\)|p-progressSpinner|skeleton|p-skeleton"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.html"
```

- **Interpretation:** Stores with loading state should have corresponding loading indicators in their feature templates.
- **True positive:** Store has `isLoading` computed but no loading indicator in the template
- **False positive:** Store has `isLoading` and template shows `@if (store.isLoading()) { <p-progressSpinner /> }` — correct
- **Confirm:** Cross-reference store files with their feature templates to verify loading indicators exist.
- **Severity:** info

---

## FE-UI-009 -- Toast notifications for mutations

**What to check:** After create/update/delete operations in store `tap` blocks, verify `MessageService.add()` is called with a translate key.

**Scan 1 -- Find mutation tap blocks:**

```
Grep pattern: "tap\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.store.ts"
     -C:      5
```

**Scan 2 -- Find MessageService usage in stores:**

```
Grep pattern: "messageService\.add|MessageService"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.store.ts"
```

- **Interpretation:** For each store with mutation operations (create/update/delete), the tap block should include a `messageService.add()` call with translated summary/detail.
- **True positive:** Store tap block after update: `tap((result) => { patchState(store, { data: result }); })` — no toast notification
- **False positive:** Store tap block: `tap((result) => { patchState(store, { data: result }); this.messageService.add({ summary: this.translate.instant('common.success'), ... }); })` — has toast
- **Confirm:** Read the store's tap blocks to verify MessageService calls exist for each mutation.
- **Severity:** info

---

## FE-UI-010 -- Extract non-trivial tab panels into components

**What to check:** Flag `<p-tabpanel>` elements whose inline content is non-trivial (forms, tables, business logic, >15 lines). Each should delegate to a child component that wraps its content in `<ui-tab-content>`.

**Scan 1 -- Find all tabpanel usages:**

```
Grep pattern: "<p-tabpanel"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
     -C:      3
```

**Scan 2 -- Check if content is a child component or inline:**

```
Grep pattern: "<p-tabpanel[^>]*>\s*<(lcb-|ui-)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **Interpretation:** For each `<p-tabpanel>`, check whether its immediate child is a dedicated component (good) or inline template content (potential violation). Count the lines between the opening and closing `<p-tabpanel>` tags — if >15 lines or contains forms/tables/event handlers, it should be extracted.
- **True positive:** `<p-tabpanel [value]="0"><div class="grid ..."><input ...><p-button ...></p-button></div></p-tabpanel>` — inline form content, should be a component
- **False positive:** `<p-tabpanel [value]="0"><lcb-company-info-tab /></p-tabpanel>` — already uses a child component (correct)
- **False positive:** `<p-tabpanel [value]="0"><ui-tab-content><p>Simple read-only text</p></ui-tab-content></p-tabpanel>` — trivially simple, inline is acceptable
- **Confirm:** Read the template to count content lines and assess complexity.
- **Severity:** info

---

## FE-UI-011 -- Use full PrimeNG tab structure

**What to check:** Flag `<p-tabs>` elements that have `<p-tablist>` but no `<p-tabpanels>` child. Tab content rendered via manual `@if (activeTab() === '...')` blocks outside the `<p-tabs>` element is a violation.

**Scan 1 -- Find all p-tabs usages:**

```
Grep pattern: "<p-tabs"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
     -C:      5
```

**Scan 2 -- Find p-tabs WITHOUT p-tabpanels (cross-reference):**

```
Grep pattern: "<p-tabpanels"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.html"
```

- **Interpretation:** Compare the two results. Any file that has `<p-tabs>` but NOT `<p-tabpanels>` is a violation. The tab content is rendered via manual `@if` blocks instead of PrimeNG's built-in panel system.
- **True positive:** `<p-tabs ...><p-tablist>...</p-tablist></p-tabs>` followed by `@if (activeTab() === 'foo') { ... }` — manual switching, should use `<p-tabpanels>/<p-tabpanel>`
- **False positive:** `<p-tabs ...><p-tablist>...</p-tablist><p-tabpanels><p-tabpanel>...</p-tabpanel></p-tabpanels></p-tabs>` — correct structure
- **Confirm:** Read the template to verify tab content is inside `<p-tabpanels>`.
- **Severity:** warning
