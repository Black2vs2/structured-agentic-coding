# Scan Playbook: Performance

Category: `performance` | Rules: FE-PERF-001 through FE-PERF-004

---

## FE-PERF-001 -- No method calls in templates

**What to check:** Flag method calls in template interpolations (`{{ method() }}`) and property bindings (`[value]="method()"`). Event handlers (`(click)="method()"`) and signal calls (`store.items()`) are acceptable.

**Scan 1 -- Method calls in interpolations:**

```
Grep pattern: "\{\{[^}]*\w+\([^)]*\)[^}]*\}\}"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

**Scan 2 -- Method calls in property bindings:**

```
Grep pattern: "\[\w+\]\s*=\s*['\"]?\w+\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `{{ getFullName(candidate) }}` — method call in interpolation, runs every CD cycle
- **True positive:** `[class]="getStatusClass(status)"` — method call in property binding
- **False positive:** `(click)="onEdit(item)"` — event handler, only runs on click
- **False positive:** `(submit)="onSubmit()"` — event handler, acceptable
- **False positive:** `{{ store.items() }}` — signal call, change-detection-aware, acceptable
- **False positive:** `{{ 'key' | translate }}` — pipe, not a method call
- **Confirm:** Distinguish between:
  1. Interpolation/binding with method call → violation
  2. Event handler `(event)="method()"` → acceptable
  3. Signal calls `signal()` → acceptable (signals track dependencies)
  4. Pipe expressions `| pipe` → acceptable
- **Severity:** warning

Note: Overlaps with FE-SIG-005. Report under FE-PERF-001 to avoid duplicates.

---

## FE-PERF-002 -- Virtual scroll for large lists

**What to check:** Large lists (>50 items) need `cdk-virtual-scroll-viewport` or PrimeNG `virtualScroll` attribute.

**Scan 1 -- Find @for loops with store data:**

```
Grep pattern: "@for.*of.*store\.\w+\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

**Scan 2 -- Find virtual scroll usage:**

```
Grep pattern: "cdk-virtual-scroll|virtualScroll|\[virtualScroll\]"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.html"
```

- **Interpretation:** Lists rendered with `@for` over store data that could contain >50 items should use virtual scrolling. Most paginated lists are already capped by page size, so this mainly applies to unbounded lists.
- **True positive:** `@for (item of store.allItems(); track item.id) {` rendering 100+ items without virtual scroll
- **False positive:** `@for (item of store.paginatedItems(); track item.id) {` — paginated list with <=50 items per page, virtual scroll not needed
- **False positive:** PrimeNG `<p-table>` with built-in pagination — table handles its own rendering
- **Confirm:** Read the store/component to determine if the list is paginated (acceptable without virtual scroll) or unbounded (needs virtual scroll).
- **Priority:** Low — requires domain knowledge of data sizes.
- **Severity:** info

---

## FE-PERF-003 -- Optimized images

**What to check:** Flag `<img>` elements without `loading`, `width`, and `height` attributes.

**Scan 1 -- Images without loading attribute:**

```
Grep pattern: "<img\s+(?![^>]*loading=)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `<img src="photo.jpg" alt="Photo">` — missing `loading="lazy"`
- **False positive:** `<img src="photo.jpg" alt="Photo" loading="lazy">` — has loading (not matched)
- **Severity:** info

**Scan 2 -- Images without width:**

```
Grep pattern: "<img\s+(?![^>]*width=)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `<img src="photo.jpg" alt="Photo" loading="lazy">` — missing width
- **Severity:** info

**Scan 3 -- Images without height:**

```
Grep pattern: "<img\s+(?![^>]*height=)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `<img src="photo.jpg" alt="Photo" loading="lazy" width="100">` — missing height
- **Severity:** info

- **Confirm:** Check if all three attributes (loading, width, height) are present. Missing any is a violation. Width and height prevent layout shift during image loading.

Note: Overlaps with DS-A11Y-001 for alt text. The reviewer should report alt text issues under DS-A11Y-001 and loading/dimensions under FE-PERF-003.

---

## FE-PERF-004 -- Track expression in @for

**What to check:** Every `@for` loop must include a `track` expression. Missing `track` causes Angular to recreate all DOM elements on each change.

**Scan 1 -- Find all @for loops:**

```
Grep pattern: "@for\s*\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

**Scan 2 -- Find @for loops with track:**

```
Grep pattern: "@for\s*\([^)]*;\s*track\s"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.html"
```

- **Interpretation:** Compare the two results. `@for` loops without `track` are violations.
- **True positive:** `@for (item of items) {` — missing `track item.id`
- **False positive:** `@for (item of items; track item.id) {` — has track expression
- **Confirm:** No confirmation needed. `@for` without `track` is a violation in all cases.
- **Severity:** warning
