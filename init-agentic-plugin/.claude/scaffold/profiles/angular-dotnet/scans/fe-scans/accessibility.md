# Scan Playbook: Accessibility

Category: `accessibility` | Rules: DS-A11Y-001 through DS-A11Y-003

---

## DS-A11Y-001 -- Images have alt text

**What to check:** Every `<img>` element must have a meaningful `alt` attribute. Flag missing alt, empty alt on non-decorative images, and generic alt text like "image", "photo", "picture".

**Scan 1 -- Images without alt attribute:**

```
Grep pattern: "<img\s+(?![^>]*alt=)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `<img src="avatar.png">` — missing alt attribute entirely
- **False positive:** `<img src="avatar.png" alt="Candidate photo">` — has meaningful alt (not matched by pattern)
- **Confirm:** No confirmation needed. Any `<img>` without `alt` is a violation.
- **Severity:** warning

**Scan 2 -- Generic alt text:**

```
Grep pattern: "alt=['\"](?:image|photo|picture|img|icon|logo)['\"]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
     -i:      true
```

- **True positive:** `alt="image"` — generic, should describe what the image shows
- **True positive:** `alt="photo"` — generic, should be descriptive like "Candidate profile photo"
- **False positive:** `alt="Company logo"` — technically generic but acceptable if it's the only logo on the page
- **Confirm:** Evaluate if the alt text provides meaningful context. Single-word generic descriptions are violations.
- **Severity:** info

**Scan 3 -- Images in templates (broader):**

```
Grep pattern: "<img\s"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **Interpretation:** List all images for manual review. Check each has: alt attribute, loading attribute, width/height.
- **Severity:** info (informational scan for contextual verification)

---

## DS-A11Y-002 -- Semantic interactive elements

**What to check:** Flag `(click)` handlers on non-interactive elements: `<div>`, `<span>`, `<p>`, `<li>`, `<tr>`. Use `<button>` or wrap content in a button.

**Scan:**

```
Grep pattern: "<(div|span|p|li|tr)\s[^>]*\(click\)="
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `<div (click)="selectItem(item)">` — should be `<button (click)="selectItem(item)">`
- **True positive:** `<span (click)="toggle()">Toggle</span>` — should be `<button type="button" (click)="toggle()">Toggle</button>`
- **True positive:** `<tr (click)="openDetail(row)">` — should use a button or anchor inside the row
- **False positive:** None — non-interactive elements should not have click handlers. All clickable elements should be `<button>`, `<a>`, or another natively interactive element.
- **Confirm:** No confirmation needed. Any match is a violation. The element should be replaced with a `<button>` or the content should be wrapped in one.
- **Severity:** warning

---

## DS-A11Y-003 -- PrimeNG aria labels

**What to check:** Icon-only `<p-button>` elements and unlabeled inputs must have an `ariaLabel` attribute.

**Scan 1 -- Icon-only buttons without ariaLabel:**

```
Grep pattern: "<p-button\s+[^>]*icon=(?![^>]*ariaLabel)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `<p-button icon="pi pi-pencil" (click)="edit()">` — missing `ariaLabel="Edit"`
- **True positive:** `<p-button icon="pi pi-trash" severity="danger">` — missing `ariaLabel="Delete"`
- **False positive:** `<p-button icon="pi pi-pencil" ariaLabel="Edit candidate">` — has aria label (not matched by pattern)
- **False positive:** `<p-button icon="pi pi-plus" label="Add">` — has visible label text, ariaLabel not needed
- **Confirm:** Check if the button has either `ariaLabel` or `label` attribute. Icon-only buttons (no `label`) MUST have `ariaLabel`. Buttons with visible `label` text are accessible without `ariaLabel`.
- **Severity:** warning

**Scan 2 -- Unlabeled inputs:**

```
Grep pattern: "<(input|p-inputText|p-select|p-inputNumber|p-calendar)\s+(?![^>]*(ariaLabel|aria-label|id=))"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `<input pInputText placeholder="Search...">` — missing ariaLabel and no associated `<label>`
- **False positive:** `<input pInputText ariaLabel="Search candidates">` — has aria label
- **False positive:** `<input pInputText id="name">` with `<label for="name">` — associated label
- **Confirm:** Read the template context to verify the input has either: (a) an `ariaLabel`/`aria-label` attribute, (b) an `id` with a matching `<label for="...">`, or (c) is wrapped in a `<label>` element.
- **Severity:** warning
