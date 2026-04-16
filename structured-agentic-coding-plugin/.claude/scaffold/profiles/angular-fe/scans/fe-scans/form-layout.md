# Scan Playbook: Form Layout

Category: `form-layout` | Rules: DS-FORM-001 through DS-FORM-003

---

## DS-FORM-001 -- 6-column grid for forms

**What to check:** Forms must use `grid-cols-6` layout. Fields span based on content type: numeric=1, medium=2, text=3, long/textarea=6.

**Scan 1 -- Find form grids with non-6 column counts:**

```
Grep pattern: "grid-cols-(?!6\b)\d+"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `class="grid grid-cols-12 gap-4"` in a form template — should be `grid-cols-6`
- **True positive:** `class="grid grid-cols-4 gap-4"` in a form template — should be `grid-cols-6`
- **False positive:** `grid-cols-3` in a non-form layout (e.g., card grid, dashboard) — 6-column rule is for forms only
- **Confirm:** Check if the grid is inside a form component (violation) vs a non-form layout (acceptable).
- **Severity:** warning

**Scan 2 -- Forms without grid at all:**

```
Grep pattern: "grid-cols"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.html"
```

- **Interpretation:** Cross-reference with form component templates (identified by having FormField). Form templates without any `grid-cols` class may be missing the grid layout entirely.
- **Confirm:** Read form component templates to verify grid layout is present.
- **Severity:** warning

---

## DS-FORM-002 -- Error display below field

**What to check:** Error messages must be positioned immediately after the input element. No layout shift. Error colors from design tokens (no hardcoded `color: red`).

**Scan 1 -- Hardcoded error colors:**

```
Grep pattern: "color:\s*red|color:\s*#[fF]{2}0{4}|color:\s*#[fF]00"
     path:    frontend/libs
     output_mode: content
     glob:    "*.{scss,html}"
```

- **True positive:** `<span style="color: red">Error message</span>` — should use design token
- **True positive:** `.error { color: #ff0000; }` — should use `var(--p-red-500)` or similar token
- **False positive:** `color: var(--p-red-500)` — uses design token, correct
- **Confirm:** No confirmation needed for hardcoded red color matches.
- **Severity:** info

**Scan 2 -- Error display structure:**

```
Grep pattern: "ngx-error|ngxError|\[err\]|error-message|field-error"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
     -C:      3
```

- **Interpretation:** Verify error display elements are positioned immediately after input elements in the DOM structure. The context lines should show the input element above the error element.
- **True positive:** Error display far from the input, separated by other form elements
- **False positive:** Error display immediately after its input within the same form field container
- **Confirm:** Read form templates to verify error-to-input positioning.
- **Severity:** info

---

## DS-FORM-003 -- Searchable selects

**What to check:** `<p-select>` and `<p-dropdown>` components must have `[filter]="true"` when they have more than 10 options.

**Scan 1 -- Find selects without filter:**

```
Grep pattern: "<p-select(?![^>]*filter)|<p-dropdown(?![^>]*filter)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

**Scan 2 -- Find selects with filter (for reference):**

```
Grep pattern: "<p-select[^>]*filter|<p-dropdown[^>]*filter"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `<p-select [options]="countries">` for a countries list (>10 options) without `[filter]="true"`
- **False positive:** `<p-select [options]="statuses">` for a status list (<10 options) — small lists don't need filtering
- **Confirm:** Read the component to determine the expected number of options. If the options come from an API call or a large enum (countries, skills, technologies), it should have filter. If it's a small static list (3-5 items like status values), filter is not required.
- **Severity:** info
