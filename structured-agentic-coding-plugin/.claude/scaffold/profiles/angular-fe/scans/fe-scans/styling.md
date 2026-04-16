# Scan Playbook: Styling

Category: `styling` | Rules: FE-STYLE-001 through FE-STYLE-003

---

## FE-STYLE-001 -- Design tokens only

**What to check:** Flag hardcoded hex/rgb/named colors (except `transparent`, `inherit`, `currentColor`) and hardcoded font sizes in SCSS files.

**Scan 1 -- Hardcoded hex colors:**

```
Grep pattern: "#[0-9a-fA-F]{3,8}"
     path:    frontend/libs
     output_mode: content
     glob:    "*.scss"
```

- **True positive:** `color: #333;` — should use `var(--p-text-color)`
- **True positive:** `background: #f0f0f0;` — should use `var(--p-surface-ground)`
- **False positive:** Colors inside `var()` calls or CSS custom property definitions (`:root { --custom: #333; }`) — defining tokens is acceptable
- **Confirm:** Check if the hex color is used directly in a property (violation) vs defined as a custom property (acceptable) or inside a `var()` call (acceptable).
- **Severity:** warning

**Scan 2 -- Hardcoded rgb/rgba/hsl colors:**

```
Grep pattern: ":\s*(rgb|rgba|hsl)\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.scss"
```

- **True positive:** `color: rgb(51, 51, 51);` — should use design token
- **True positive:** `background: rgba(0, 0, 0, 0.5);` — should use `var(--p-mask-background)` or similar
- **False positive:** None — rgb/rgba/hsl should not be hardcoded in component SCSS
- **Confirm:** No confirmation needed. Hardcoded color functions are violations.
- **Severity:** warning

**Scan 3 -- Hardcoded font sizes:**

```
Grep pattern: "font-size:\s*\d+"
     path:    frontend/libs
     output_mode: content
     glob:    "*.scss"
```

- **True positive:** `font-size: 14px;` — should use `var(--p-font-size)` or Tailwind `text-sm`
- **False positive:** `font-size: var(--p-font-size);` — uses token (not matched)
- **Confirm:** No confirmation needed. Hardcoded font sizes are violations.
- **Severity:** warning

Note: This rule overlaps significantly with DS-VISUAL-002 (fonts), DS-VISUAL-003 (colors), and DS-VISUAL-006 (spacing). The reviewer should deduplicate — report hex colors under DS-VISUAL-003, font sizes under DS-VISUAL-002, and spacing under DS-VISUAL-006. Only report under FE-STYLE-001 if the finding doesn't fit those more specific categories.

---

## FE-STYLE-002 -- No !important without justification

**What to check:** Flag `!important` usage in SCSS without a comment on the same or preceding line explaining why it's needed.

**Scan:**

```
Grep pattern: "!important"
     path:    frontend/libs
     output_mode: content
     glob:    "*.scss"
     -B:      1
```

- **True positive:** `color: red !important;` with no comment on the line or preceding line
- **False positive:** `/* Override PrimeNG default */ color: var(--p-primary-color) !important;` — has justification comment
- **False positive:** `// Override PrimeNG default theme\n  color: var(--p-primary-color) !important;` — comment on preceding line
- **Confirm:** Check the -B=1 context output. If the preceding line contains a comment (starting with `//` or `/*`), the !important is justified. If no comment exists, it's a violation.
- **Severity:** info

---

## FE-STYLE-003 -- No barrel import bloat

**What to check:** Flag library root imports when deep imports are available.

**Note:** This rule's scan is identical to FE-API-004. The reviewer should deduplicate — run the FE-API-004 scan and report all findings under FE-API-004.

**Scan (for reference, same as FE-API-004):**

```
Grep pattern: "from ['\"]primeng['\"]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `import { X } from 'primeng'` — root import
- **False positive:** `import { X } from 'primeng/x'` — deep import, correct (not matched)
- **Severity:** warning

No separate scan needed — deduplicate with FE-API-004.
