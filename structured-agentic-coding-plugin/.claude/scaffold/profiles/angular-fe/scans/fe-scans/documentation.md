# Scan Playbook: Documentation

Category: `documentation` | Rules: DOC-001 through DOC-004

---

## DOC-001 -- ARCHITECTURE.md for significant libraries

**What to check:** Core libraries (libs/core/{lib}), feature libraries (libs/features/{lib}), page libraries (libs/pages/{lib}), and the UI library (libs/ui/) with 3+ source files must have an ARCHITECTURE.md.

**Scan 1 -- Core libraries without ARCHITECTURE.md:**

```
Glob pattern: "frontend/libs/core/*/ARCHITECTURE.md"
```

Cross-reference against: `Glob("frontend/libs/core/*/")`.
Exclude: `api/` (generated code, no architecture doc needed).
For each lib dir missing the file, confirm it has 3+ `.ts` files (excluding `*.spec.ts`).

- **True positive:** Core library (e.g., `auth/`, `store/`, `forms/`) with 3+ source files and no `ARCHITECTURE.md`
- **False positive:** `api/` library (generated code). Libraries with fewer than 3 non-spec `.ts` files.
- **Confirm:** `Glob("{dir}/**/*.ts")` excluding `*.spec.ts` to count source files.
- **Severity:** warning

**Scan 2 -- Feature libraries without ARCHITECTURE.md:**

```
Glob pattern: "frontend/libs/features/*/ARCHITECTURE.md"
```

Cross-reference against: `Glob("frontend/libs/features/*/")`.
For each lib dir missing the file, confirm it has 3+ `.ts` files (excluding `*.spec.ts`).

- **True positive:** Feature library with 3+ source files and no `ARCHITECTURE.md`
- **False positive:** Libraries with fewer than 3 non-spec `.ts` files
- **Confirm:** Count non-spec `.ts` files.
- **Severity:** warning

**Scan 3 -- Page libraries without ARCHITECTURE.md:**

```
Glob pattern: "frontend/libs/pages/*/ARCHITECTURE.md"
```

Cross-reference against: `Glob("frontend/libs/pages/*/")`.
Same logic as Scan 2.

- **True positive:** Page library with 3+ source files and no `ARCHITECTURE.md`
- **False positive:** Libraries with fewer than 3 non-spec `.ts` files
- **Confirm:** Count non-spec `.ts` files.
- **Severity:** warning

**Scan 4 -- UI library without ARCHITECTURE.md:**

```
Glob pattern: "frontend/libs/ui/ARCHITECTURE.md"
```

Check if `frontend/libs/ui/` has 3+ `.ts` files (excluding `*.spec.ts`).

- **True positive:** UI library with 3+ source files and no `ARCHITECTURE.md`
- **False positive:** UI library with fewer than 3 non-spec `.ts` files (unlikely)
- **Confirm:** Count non-spec `.ts` files.
- **Severity:** warning

---

## DOC-002 -- GUIDELINES.md for significant libraries

**What to check:** Same libraries as DOC-001 must have a GUIDELINES.md.

Run the same four scans as DOC-001 but check for `GUIDELINES.md` instead:

**Scan 1 -- Core libraries:**

```
Glob pattern: "frontend/libs/core/*/GUIDELINES.md"
```

**Scan 2 -- Feature libraries:**

```
Glob pattern: "frontend/libs/features/*/GUIDELINES.md"
```

**Scan 3 -- Page libraries:**

```
Glob pattern: "frontend/libs/pages/*/GUIDELINES.md"
```

**Scan 4 -- UI library:**

```
Glob pattern: "frontend/libs/ui/GUIDELINES.md"
```

Same cross-referencing, exclusions, and confirmation logic as DOC-001.

---

## DOC-003 -- ARCHITECTURE.md minimum sections

**What to check:** Existing ARCHITECTURE.md files must have at minimum: a heading with module name, a Purpose section, a Components/Structure section, and a Key Decisions section.

**Scan:**

```
Grep pattern: "^## (Purpose|Structure|Components|Key Decisions)"
     path:    {each existing ARCHITECTURE.md}
     output_mode: content
```

- **True positive:** File exists but missing one of the required sections (Purpose, Structure/Components, Key Decisions)
- **False positive:** Section exists under a different but equivalent heading (e.g., "## Overview" instead of "## Purpose", "## Frontend Components" instead of "## Components")
- **Confirm:** Read the file to check for equivalent sections if Grep returns fewer than 3 of the expected headings. Accept headings that contain the key word (e.g., "## Frontend Components" satisfies "Components").
- **Severity:** warning

---

## DOC-004 -- GUIDELINES.md minimum sections

**What to check:** Existing GUIDELINES.md files must have at minimum: a heading with module name, a Patterns section, and a Conventions section.

**Scan:**

```
Grep pattern: "^## (Patterns|Conventions|Do|Don't)"
     path:    {each existing GUIDELINES.md}
     output_mode: content
```

- **True positive:** File exists but missing Patterns or Conventions section
- **False positive:** Section exists under an equivalent heading (e.g., "## Coding Patterns" instead of "## Patterns")
- **Confirm:** Read the file to check for equivalent sections if Grep returns fewer than 2 of the expected headings. Accept headings that contain the key word.
- **Severity:** warning
