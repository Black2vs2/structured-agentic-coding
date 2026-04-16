# Scan Playbook: Visual Consistency

Category: `visual-consistency` | Rules: DS-VISUAL-001 through DS-VISUAL-006

---

## DS-VISUAL-001 -- Component reuse before creation

**What to check:** Before creating a new UI component, search `libs/ui/` and PrimeNG for an existing match.

**Note:** This rule is not scannable via Grep. It applies during code generation/review of new components, not during automated scanning. The reviewer should note if a custom component duplicates existing PrimeNG or shared UI functionality during contextual verification.

- **Severity:** info

---

## DS-VISUAL-002 -- Font sizes from tokens

**What to check:** Flag hardcoded `font-size` values in SCSS. Accept `var()`, Tailwind classes, and PrimeNG variables.

**Scan:**

```
Grep pattern: "font-size\s*:\s*\d+"
     path:    frontend/libs
     output_mode: content
     glob:    "*.scss"
```

- **True positive:** `font-size: 14px;` — should use `var(--p-font-size)` or Tailwind `text-sm`
- **True positive:** `font-size: 12px;` — should use `var(--p-font-size-sm)` or Tailwind `text-xs`
- **True positive:** `font-size: 16px;` — should use `var(--p-font-size-lg)` or Tailwind `text-base`
- **False positive:** `font-size: var(--p-font-size);` — uses design token, correct (not matched by this pattern)
- **Confirm:** No confirmation needed. Any hardcoded pixel value for font-size is a violation.
- **Severity:** warning

Note: Overlaps with FE-STYLE-001. The reviewer should deduplicate — report under DS-VISUAL-002 for font-size violations.

---

## DS-VISUAL-003 -- Colors from tokens

**What to check:** Flag hardcoded color values (hex, rgb, rgba, hsl). Accept `transparent`, `inherit`, `currentColor`, and `var()` calls.

**Scan 1 -- Hardcoded hex colors:**

```
Grep pattern: "(color|background|border).*:\s*#[0-9a-fA-F]{3,8}"
     path:    frontend/libs
     output_mode: content
     glob:    "*.scss"
```

**Scan 2 -- Hardcoded rgb/rgba/hsl colors:**

```
Grep pattern: "(color|background|border).*:\s*(rgb|rgba|hsl)\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.scss"
```

- **True positive:** `color: #333333;` — should use `var(--p-text-color)`
- **True positive:** `background: #f5f5f5;` — should use `var(--p-surface-ground)`
- **True positive:** `border-color: rgb(200, 200, 200);` — should use `var(--p-surface-border)`
- **False positive:** `color: transparent;` — acceptable keyword
- **False positive:** `color: inherit;` — acceptable keyword
- **False positive:** `color: currentColor;` — acceptable keyword
- **False positive:** `color: var(--p-text-color);` — uses design token (not matched by these patterns)
- **Confirm:** No confirmation needed for hex/rgb matches. They are violations unless inside a `var()` call.
- **Severity:** warning

Note: Overlaps with FE-STYLE-001. The reviewer should deduplicate — report under DS-VISUAL-003 for color violations.

---

## DS-VISUAL-004 -- Consistent date format

**What to check:** Flag `| date` pipe with hardcoded format strings. Use the shared date pipe or a centralized format constant.

**Scan:**

```
Grep pattern: "\| date\s*:\s*['\"]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `{{ createdAt | date:'dd/MM/yyyy' }}` — should use shared date format
- **True positive:** `{{ date | date:'yyyy-MM-dd HH:mm' }}` — hardcoded format
- **False positive:** `{{ date | date:DATE_FORMAT }}` — uses a constant, acceptable
- **Confirm:** Check if the format string is hardcoded (violation) vs a constant reference (acceptable).
- **Severity:** info

---

## DS-VISUAL-005 -- Enums as badges

**What to check:** Flag raw text display of enum/status values without badge/chip wrapper.

**Scan (heuristic):**

```
Grep pattern: "\{\{\s*\w*\.(status|type|seniority|level|priority)\s*(\(\))?\s*\}\}"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `{{ candidate.seniority }}` — raw enum text display, should use a badge/chip component
- **True positive:** `{{ invite.status() }}` — raw signal status display without chip
- **False positive:** `{{ candidate.seniority }}` inside a `<p-tag>` or chip wrapper component — already displayed as badge
- **Confirm:** Read the template context around the match to check if it's inside a chip/badge/tag component (acceptable) or raw text (violation).
- **Severity:** info

---

## DS-VISUAL-006 -- Spacing from tokens

**What to check:** Flag hardcoded pixel values in margin, padding, and gap. Use Tailwind utilities or CSS variables.

**Scan:**

```
Grep pattern: "(margin|padding|gap)\s*:\s*\d+px"
     path:    frontend/libs
     output_mode: content
     glob:    "*.scss"
```

- **True positive:** `margin: 8px;` — should use Tailwind `m-2` or CSS variable
- **True positive:** `padding: 16px;` — should use Tailwind `p-4` or CSS variable
- **True positive:** `gap: 12px;` — should use Tailwind `gap-3` or CSS variable
- **False positive:** Values inside `var()` calls: `margin: var(--spacing-md)` — uses token (not matched)
- **False positive:** `margin: 0;` — zero values don't need tokens (not matched by pattern requiring `px`)
- **Confirm:** No confirmation needed. Hardcoded px values for spacing are violations.
- **Severity:** info

Note: Overlaps with FE-STYLE-001. The reviewer should deduplicate — report under DS-VISUAL-006 for spacing violations.
