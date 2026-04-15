# Scan Playbook: Environment Variables

Category: `env` | Rules: FE-ENV-001 through FE-ENV-003

---

## FE-ENV-001 — import.meta.env.VITE_* only

**What to check:** No `process.env.*` access in frontend code.

**Scan:**
```
Grep pattern: "process\\.env\\."
     path:    __FE_DIR__/src
     output_mode: content
```

- **True positive:** Any `process.env.FOO` in `src/`.
- **False positive:** None — `process.env` doesn't exist in Vite's browser bundle.
- **Confirm:** No confirmation needed.
- **Severity:** error

---

## FE-ENV-002 — Env types declared in vite-env.d.ts

**What to check:** Every `VITE_*` variable used in the codebase is declared in `src/vite-env.d.ts`'s `ImportMetaEnv` interface.

**Scan:**
```
Grep pattern: "import\\.meta\\.env\\.VITE_\\w+"
     path:    __FE_DIR__/src
     output_mode: content
```
Collect all distinct var names. Then read `__FE_DIR__/src/vite-env.d.ts` and verify each is declared.

- **True positive:** Code uses `import.meta.env.VITE_API_URL` but `vite-env.d.ts` doesn't declare `VITE_API_URL: string`.
- **False positive:** Env var declared under a different name (e.g., optional `VITE_API_URL?: string`) — still valid.
- **Confirm:** Read the interface; missing declarations are violations.
- **Severity:** warning

---

## FE-ENV-003 — No committed .env files

**What to check:** `.env*` files (except `.env.example`) are gitignored.

**Scan:**
```
Glob pattern: __FE_DIR__/.env
Glob pattern: __FE_DIR__/.env.local
Glob pattern: __FE_DIR__/.env.production
Glob pattern: __FE_DIR__/.env.staging
```
For each match, check if git tracks it:
```
Bash: cd __FE_DIR__ && git ls-files .env* 2>/dev/null
```

- **True positive:** `.env.production` present and tracked by git.
- **False positive:** `.env.example` with placeholder values is the committed template — OK.
- **Confirm:** Check whether the file is in `.gitignore`. Read the file for actual secret values.
- **Severity:** error
