# Scan Playbook: Bun Package Manager

Category: `package-manager` | Rules: FE-BUN-001 through FE-BUN-003

---

## FE-BUN-001 — Only bun.lock committed

**What to check:** Only `bun.lock` (or `bun.lockb`) is present; no competing lockfiles.

**Scan:**
```
Glob pattern: ./package-lock.json
Glob pattern: ./yarn.lock
Glob pattern: ./pnpm-lock.yaml
```

Any of those present is a violation.

- **True positive:** `yarn.lock` or `package-lock.json` at the project root.
- **False positive:** None — bun is the only supported manager.
- **Confirm:** No confirmation needed.
- **Severity:** error

---

## FE-BUN-002 — CI uses bun commands

**What to check:** GitHub Actions workflows install and run scripts via bun.

**Scan:**
```
Grep pattern: "\\b(npm install|npm ci|yarn install|pnpm install)\\b"
     path:    ./.github/workflows
     output_mode: content
```
Also:
```
Grep pattern: "\\bnpm run\\b|\\byarn\\s+run\\b|\\bpnpm\\s+run\\b"
     path:    ./.github/workflows
     output_mode: content
```

- **True positive:** Workflow step running `npm install` or `npm run build`.
- **False positive:** Comments or docstrings referencing alternatives.
- **Confirm:** Only actual command lines count.
- **Severity:** warning

---

## FE-BUN-003 — Scripts run via bun run

**What to check:** Docs (`README.md`, `CLAUDE.md`) instruct users to run scripts via bun.

**Scan:**
```
Grep pattern: "\\b(npm run|yarn run|pnpm run)\\s+(dev|build|test|format|lint)"
     path:    .
     output_mode: content
```
Restrict to markdown files.

- **True positive:** `README.md` says `npm run dev` to start the server.
- **False positive:** Historical notes mentioning past migration from npm — OK if clearly marked.
- **Confirm:** Check the context; active instructions should use bun.
- **Severity:** info
