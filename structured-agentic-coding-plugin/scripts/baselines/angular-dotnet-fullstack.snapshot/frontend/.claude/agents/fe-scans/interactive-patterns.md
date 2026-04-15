# Scan Playbook: Interactive Patterns

Category: `interactive-patterns` | Rules: DS-INTERACT-001 through DS-INTERACT-004

---

## DS-INTERACT-001 -- Routed tabs for shareable state

**What to check:** Tabs that load different data must use child routes (not `activeIndex` state). Cosmetic form groupings are exempt.

**Scan 1 -- Find tab usage:**

```
Grep pattern: "<p-tabPanel|<p-tabs|<p-tabView|activeIndex"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

**Scan 2 -- Check for child routes in corresponding route files:**

```
Grep pattern: "children\s*:"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.routes.ts"
```

- **Interpretation:** Components with tabs that load different data (identified by data-fetching logic per tab) should use child routes for URL-addressable tabs. Tabs used for cosmetic grouping (e.g., grouping form sections) are exempt.
- **True positive:** `<p-tabView [(activeIndex)]="selectedTab">` with different API calls per tab panel — should use routed tabs with child routes
- **False positive:** `<p-tabView>` with static content or form sections — cosmetic grouping, exempt
- **Confirm:** Read the component to determine if each tab loads different data (needs routes) vs groups static/form content (cosmetic, exempt).
- **Severity:** info

---

## DS-INTERACT-002 -- Table row actions as inline buttons

**What to check:** Table row actions must be always-visible inline buttons in the last column. Flag hidden menus, dropdowns, or hover-reveal patterns for row actions.

**Scan 1 -- Menu components inside table templates:**

```
Grep pattern: "<p-menu|<p-splitButton|<p-contextMenu"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

**Scan 2 -- Hover-reveal patterns in table SCSS:**

```
Grep pattern: "(mouseenter)|:hover.*display|:hover.*visibility|:hover.*opacity"
     path:    frontend/libs
     output_mode: content
     glob:    "*.{scss,html}"
```

- **True positive:** `<p-menu [model]="rowActions">` inside a table column — should be inline `<p-button>` elements
- **True positive:** `<td class="actions" (mouseenter)="showActions()">` — hover-reveal pattern for row actions
- **False positive:** `<p-menu>` used for page-level navigation or toolbar actions (not inside a table) — acceptable
- **Confirm:** Check if the menu/hover pattern is inside a table row (violation) vs page-level navigation (acceptable). Read the template structure to verify context.
- **Severity:** warning

---

## DS-INTERACT-003 -- Loading indicators everywhere

**What to check:** Every loading signal in a store needs a corresponding loading indicator in the template. Use skeletons for content areas, spinners for blocking operations.

**Scan 1 -- Find loading signals in stores:**

```
Grep pattern: "isLoading|loading\(\)"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.store.ts"
```

**Scan 2 -- Find loading indicators in templates:**

```
Grep pattern: "isLoading|loading\(\)|p-progressSpinner|p-skeleton|skeleton"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.html"
```

- **Interpretation:** Every store file with a loading signal should have a corresponding template file with a loading indicator. Cross-reference by feature path.
- **True positive:** Store at `frontend/libs/features/candidates/src/lib/candidates.store.ts` has `isLoading` but `list.component.html` has no loading indicator
- **False positive:** Store has `isLoading` and template shows `@if (store.isLoading()) { <p-progressSpinner /> }`
- **Confirm:** For each store with loading state, verify the corresponding template references it with a visible indicator.
- **Severity:** info

Note: Overlaps with FE-UI-008. Report under DS-INTERACT-003 to avoid duplicates.

---

## DS-INTERACT-004 -- Button placement consistency

**What to check:** Page actions go in `<ui-page-header>` right-aligned. Dialog buttons go bottom-right. Destructive buttons must have `severity="danger"`.

**Scan 1 -- Destructive buttons without danger severity:**

```
Grep pattern: "(click)=\".*delete|(click)=\".*remove|(click)=\".*revoke"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
     -C:      2
```

- **Interpretation:** Check if buttons with destructive click handlers have `severity="danger"` on the `<p-button>` element.
- **True positive:** `<p-button (click)="delete(item.id)" label="Delete">` without `severity="danger"`
- **False positive:** `<p-button (click)="delete(item.id)" severity="danger" label="Delete">` — has danger severity
- **Confirm:** Read the context around destructive click handlers to verify severity attribute.
- **Severity:** info

**Scan 2 -- Save/action buttons outside page header:**

```
Grep pattern: "(click)=\".*save\(|(click)=\".*submit\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **Interpretation:** Cross-reference with `<ui-page-header>` context. Save/submit buttons on detail pages should be inside the page header, not floating in the content area.
- **True positive:** Save button in the form component template instead of the page component's `<ui-page-header>`
- **False positive:** Save button correctly placed inside `<ui-page-header>` right slot
- **Confirm:** Read the template to verify the save button location relative to `<ui-page-header>`.
- **Severity:** info

Note: Overlaps with FE-UI-004. Report under DS-INTERACT-004 for placement issues.
