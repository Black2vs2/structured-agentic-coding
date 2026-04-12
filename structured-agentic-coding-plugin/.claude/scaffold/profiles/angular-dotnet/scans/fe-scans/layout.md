# Scan Playbook: Page Shell & Layout

Category: `layout` | Rules: DS-LAYOUT-001 through DS-LAYOUT-003

---

## DS-LAYOUT-001 -- Topbar and sidebar always visible

**What to check:** The application shell must always display topbar and sidebar. Flag `display: none`, `visibility: hidden`, or `@if` conditionally hiding them. Login page is exempt.

**Scan 1 -- Hidden shell elements in SCSS:**

```
Grep pattern: "display:\s*none|visibility:\s*hidden"
     path:    frontend/src
     output_mode: content
     glob:    "*.scss"
```

**Scan 2 -- Hidden shell elements in global styles:**

```
Grep pattern: "display:\s*none|visibility:\s*hidden"
     path:    frontend/libs/ui
     output_mode: content
     glob:    "*.scss"
```

**Scan 3 -- Conditional hiding in layout templates:**

```
Grep pattern: "@if.*topbar|@if.*sidebar|@if.*nav|\*ngIf.*topbar|\*ngIf.*sidebar"
     path:    frontend/src
     output_mode: content
     glob:    "*.html"
     -i:      true
```

- **True positive:** `.sidebar { display: none; }` in a non-login-related SCSS file
- **True positive:** `@if (showSidebar) { <app-sidebar /> }` — sidebar visibility should not be conditional
- **False positive:** Same patterns in login page styles/templates — login is exempt from shell requirements
- **False positive:** Media query hiding for responsive design (`@media (max-width: 768px) { .sidebar { display: none; } }`) — responsive behavior is acceptable
- **Confirm:** Check if the hiding is global (violation) vs login-specific (acceptable) vs responsive (acceptable).
- **Severity:** warning

---

## DS-LAYOUT-002 -- Only content area scrolls

**What to check:** Topbar and sidebar should be `position: fixed` or `position: sticky`. Main content area should have `overflow-y: auto`. No `overflow` on `body`.

**Scan 1 -- Check for overflow on body/html:**

```
Grep pattern: "(body|html)\s*\{[^}]*overflow"
     path:    frontend/src
     output_mode: content
     glob:    "*.scss"
     multiline: true
```

**Scan 2 -- Check shell positioning:**

```
Grep pattern: "position:\s*(fixed|sticky)"
     path:    frontend/src
     output_mode: content
     glob:    "*.scss"
```

**Scan 3 -- Content area overflow:**

```
Grep pattern: "overflow-y:\s*auto|overflow-y:\s*scroll"
     path:    frontend/src
     output_mode: content
     glob:    "*.scss"
```

- **Interpretation:** Verify the architectural pattern: topbar/sidebar have fixed/sticky positioning, content area has overflow-y: auto. If none of these patterns are found, the layout may not follow the fixed-shell pattern.
- **True positive:** `body { overflow: auto; }` — body should not scroll, only the content area
- **True positive:** Topbar/sidebar without `position: fixed` or `position: sticky`
- **False positive:** `overflow: hidden` on body — this is correct (prevents body scrolling)
- **Confirm:** Read the shell/layout component SCSS to verify the complete layout structure.
- **Severity:** warning

---

## DS-LAYOUT-003 -- Table headers fixed while scrolling

**What to check:** PrimeNG tables must have `scrollable="true"` and `scrollHeight`. Custom tables need sticky thead.

**Scan 1 -- PrimeNG tables without scrollable:**

```
Grep pattern: "<p-table(?![^>]*scrollable)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

**Scan 2 -- PrimeNG tables with scrollable (for reference):**

```
Grep pattern: "<p-table[^>]*scrollable"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

**Scan 3 -- Custom tables without sticky:**

```
Grep pattern: "<table\b"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.html"
```

- **True positive:** `<p-table [value]="items">` without `scrollable="true"` and `scrollHeight` — headers won't stick
- **False positive:** `<p-table [value]="items" scrollable="true" scrollHeight="flex">` — correct
- **False positive:** Small tables with few rows where scrolling isn't needed
- **Confirm:** Read the template to check if the table has enough rows to warrant scrollable behavior. Tables in list/index pages should always be scrollable.
- **Severity:** info
