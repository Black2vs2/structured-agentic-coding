# Scan Playbook: CI & Deploy

Category: `ci` | Rules: BE-CI-001 through BE-CI-004

---

## BE-CI-001 — Bun-only package manager

**What to check:** Only `bun.lock` (or `bun.lockb`) is present; no competing lockfiles. CI workflows use bun.

**Scan:**
```
Glob pattern: __BE_DIR__/package-lock.json
Glob pattern: __BE_DIR__/yarn.lock
Glob pattern: __BE_DIR__/pnpm-lock.yaml
```
Any of these present is a violation.

Also:
```
Grep pattern: "\\b(npm install|npm ci|yarn install|pnpm install)\\b"
     path:    __BE_DIR__/.github/workflows
     output_mode: content
```
CI commands should be `bun install` / `bun run <script>`.

- **True positive:** Any competing lockfile; any npm/yarn/pnpm install command in CI.
- **False positive:** Comments or docs in workflow files mentioning alternatives.
- **Confirm:** Read the YAML; only actual command lines count.
- **Severity:** error (lockfile present), warning (CI mentions)

---

## BE-CI-002 — Secrets parity cloudbuild.yaml vs deploy-*.yml

**What to check:** The `--set-secrets` argument list must be identical between `cloudbuild.yaml` and `.github/workflows/deploy-{stage,prod}.yml`.

**Scan:**
```
Grep pattern: "--set-secrets"
     path:    __BE_DIR__
     output_mode: content
     -A:      30
```
Collect the full secret list from each match. Diff the lists.

- **True positive:** A secret present in `cloudbuild.yaml` but absent in one of `deploy-*.yml` (or vice versa).
- **False positive:** Secrets intentionally env-specific (e.g., `STRIPE_SECRET_STAGE` in deploy-stage.yml only). These need a comment flagging the intent.
- **Confirm:** Build the lists manually; any mismatch is a violation unless annotated.
- **Severity:** error

---

## BE-CI-003 — Multi-stage Dockerfile

**What to check:** `Dockerfile` uses `FROM ... AS builder` + a separate final stage.

**Scan:**
```
Grep pattern: "^FROM "
     path:    __BE_DIR__/Dockerfile
     output_mode: content
```

- **True positive:** Only one FROM line, or final stage inheriting from the builder without dropping dev dependencies.
- **False positive:** A legitimate single-stage Dockerfile for a tiny service (rare — flag for confirmation).
- **Confirm:** Read the Dockerfile; final stage must NOT contain dev dependencies, test sources, or `.env` files.
- **Severity:** warning

Also check for leaked `.env` files:
```
Grep pattern: "^COPY .*\\.env"
     path:    __BE_DIR__/Dockerfile
     output_mode: content
```
Any match is an error.

---

## BE-CI-004 — Migrations run before container starts

**What to check:** Deploy workflow runs `__MIGRATION_RUN__` before the new Cloud Run revision receives traffic.

**Scan:**
```
Grep pattern: "migration:run|__MIGRATION_RUN__"
     path:    __BE_DIR__/.github/workflows
     output_mode: content
     -B:      5
     -A:      10
```
Also check `cloudbuild.yaml`:
```
Grep pattern: "migration:run"
     path:    __BE_DIR__/cloudbuild.yaml
     output_mode: content
```

- **True positive:** No migration step in the deploy path.
- **False positive:** Migrations run from a separate workflow that's always triggered before deploy (requires reading the CI DAG).
- **Confirm:** Trace the deploy workflow step order; migrations must complete before `gcloud run deploy` OR before the new revision serves traffic.
- **Severity:** error
