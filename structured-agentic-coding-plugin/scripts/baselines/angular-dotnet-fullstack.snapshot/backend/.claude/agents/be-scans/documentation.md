# Scan Playbook: Documentation

Category: `documentation` | Rules: DOC-001 through DOC-004

---

## DOC-001 -- ARCHITECTURE.md for significant modules

**What to check:** Backend layer directories (Domain, Application, Api, Migrations), feature directories (Application/{Feature}), and module directories (Api/{Module}) with 3+ source files must have an ARCHITECTURE.md.

**Scan 1 -- Backend layer directories without ARCHITECTURE.md:**

```
Glob pattern: "backend/src/App.*/ARCHITECTURE.md"
```

Cross-reference against expected dirs: `Domain`, `Application`, `Api`, `Migrations`.
Missing = finding.

- **True positive:** Layer directory with 3+ `.cs` files and no `ARCHITECTURE.md`
- **False positive:** Directory with fewer than 3 source files
- **Confirm:** Count source files with `Glob("{dir}/**/*.cs")` if uncertain.
- **Severity:** warning

**Scan 2 -- Feature directories without ARCHITECTURE.md:**

```
Glob pattern: "backend/src/App.Application/*/ARCHITECTURE.md"
```

Cross-reference against: `Glob("backend/src/App.Application/*/")`.
For each feature dir missing the file, confirm it has 3+ `.cs` files.

- **True positive:** Feature directory with 3+ source files and no `ARCHITECTURE.md`
- **False positive:** Feature directory with fewer than 3 source files (e.g., a `Common/` folder with just a few helpers)
- **Confirm:** `Glob("{dir}/**/*.cs")` to count source files.
- **Severity:** warning

**Scan 3 -- Module directories without ARCHITECTURE.md:**

```
Glob pattern: "backend/src/App.Api/*/ARCHITECTURE.md"
```

Cross-reference against: `Glob("backend/src/App.Api/*/")`.
Exclude: `Controllers/` (thin, no architecture needed), `OpenApi/` (single file).

- **True positive:** Module directory (e.g., `Auth/`) with 3+ source files and no `ARCHITECTURE.md`
- **False positive:** `Controllers/` directory (thin controllers don't need architecture docs). `OpenApi/` directory (single-file configuration).
- **Confirm:** Check exclusion list first, then count source files if not excluded.
- **Severity:** warning

---

## DOC-002 -- GUIDELINES.md for significant modules

**What to check:** Same directories as DOC-001 must have a GUIDELINES.md.

Run the same three scans as DOC-001 but check for `GUIDELINES.md` instead:

**Scan 1 -- Layer directories:**
```
Glob pattern: "backend/src/App.*/GUIDELINES.md"
```

**Scan 2 -- Feature directories:**
```
Glob pattern: "backend/src/App.Application/*/GUIDELINES.md"
```

**Scan 3 -- Module directories:**
```
Glob pattern: "backend/src/App.Api/*/GUIDELINES.md"
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
- **False positive:** Section exists under a different but equivalent heading (e.g., "## Overview" instead of "## Purpose", "## Backend Components" instead of "## Components")
- **Confirm:** Read the file to check for equivalent sections if Grep returns fewer than 3 of the expected headings. Accept headings that contain the key word (e.g., "## Backend Components" satisfies "Components").
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
