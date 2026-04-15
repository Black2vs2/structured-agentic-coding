# Scan Playbook: UI & Theming

Category: `ui` | Rules: FE-UI-001 through FE-UI-005

---

## FE-UI-001 — shadcn components from components/ui/

**What to check:** UI primitives (Button, Input, Dialog, Select, Dropdown, etc.) are imported from `src/components/ui/`, not directly from Radix.

**Scan:**
```
Grep pattern: "from ['\"]@radix-ui/react-(button|input|dialog|select|dropdown-menu|checkbox|switch|popover|tooltip|avatar)['\"]"
     path:    ./src
     output_mode: content
```
A direct Radix import where the shadcn wrapper exists in `components/ui/` is a violation.

- **True positive:** `import { Dialog } from '@radix-ui/react-dialog'` in a resource page when `src/components/ui/dialog.tsx` exists.
- **False positive:** Importing from Radix inside `src/components/ui/*.tsx` itself — that's the shadcn wrapper implementation.
- **Confirm:** Check whether the corresponding shadcn wrapper exists.
- **Severity:** warning

---

## FE-UI-002 — Tailwind 4 via @tailwindcss/vite

**What to check:** Vite config uses `@tailwindcss/vite`.

**Scan:**
```
Grep pattern: "@tailwindcss/vite"
     path:    ./vite.config.ts
     output_mode: content
```
Missing is a violation. Also check for legacy remnants:
```
Grep pattern: "postcss\\.config|tailwind\\.config\\.(js|cjs|ts)"
     path:    .
     output_mode: files_with_matches
```
Legacy PostCSS-based Tailwind config should be removed.

- **True positive:** `vite.config.ts` missing `@tailwindcss/vite` import / plugin, OR `postcss.config.js` still present with Tailwind config.
- **False positive:** `tailwind.config.ts` retained for content path configuration (Tailwind 4 still supports optional config).
- **Confirm:** Read the config files; Tailwind 4 requires the Vite plugin, legacy PostCSS setup is obsolete.
- **Severity:** warning

---

## FE-UI-003 — No hardcoded hex colors in components

**What to check:** Components use CSS variables or Tailwind utilities, not literal hex values.

**Scan:**
```
Grep pattern: "(bg|text|border|ring)-\\[#[0-9a-fA-F]{3,8}\\]"
     path:    ./src
     output_mode: content
```
Also:
```
Grep pattern: "#[0-9a-fA-F]{6}"
     path:    ./src/components
     output_mode: content
```
And style props:
```
Grep pattern: "style=\\{\\s*\\{[^}]*color\\s*:\\s*['\"]#"
     path:    ./src
     output_mode: content
```

- **True positive:** `className="bg-[#132642]"` or `style={{ color: '#FF0000' }}`.
- **False positive:** Hex in `src/index.css` (CSS variable declarations), hex in documentation/comments.
- **Confirm:** Check the file is a component, not the theme declaration.
- **Severity:** warning

---

## FE-UI-004 — Emotion secondary to Tailwind+shadcn

**What to check:** Emotion's `styled` is rarely used; primary styling is Tailwind + shadcn.

**Scan:**
```
Grep pattern: "from ['\"]@emotion/styled['\"]"
     path:    ./src
     output_mode: content
     -B:      3
```
Count matches; if > 5 files use Emotion directly, consider systemic issue. For each match, check for a justification comment.

- **True positive:** Widespread Emotion usage in component files without comments justifying why Tailwind can't express the style.
- **False positive:** Isolated Emotion use for animation keyframes or truly dynamic styles with comments.
- **Confirm:** Read each file; legitimate cases have brief comments explaining the choice.
- **Severity:** info (individual), warning (widespread)

---

## FE-UI-005 — Icons from lucide-react

**What to check:** All icon imports come from `lucide-react`.

**Scan:**
```
Grep pattern: "from ['\"]@(heroicons|tabler/icons-react|fortawesome)"
     path:    ./src
     output_mode: content
```
Also:
```
Grep pattern: "from ['\"]react-icons"
     path:    ./src
     output_mode: content
```

- **True positive:** Icon imports from heroicons, tabler, fortawesome, react-icons.
- **False positive:** None — stick with lucide-react for consistency.
- **Confirm:** No confirmation needed.
- **Severity:** warning
