# Scan Playbook: Queue (pg-boss)

Category: `queue` | Rules: BE-QUEUE-001 through BE-QUEUE-003

---

## BE-QUEUE-001 — Job handlers idempotent

**What to check:** `.work()` handlers that perform non-idempotent writes must include a dedup check.

**Scan:**
```
Grep pattern: "\\.work\\s*\\("
     path:    __BE_DIR__/src
     output_mode: content
     -A:      30
```
For each match, read the handler body. Flag if it performs `INSERT`/`save` without an `ON CONFLICT`, unique-key check, or dedup-by-key pattern near the top.

- **True positive:** `.work('email.send', async (job) => { await repo.save(new Email(job.data)); })` — no dedup.
- **False positive:** Handlers that only read/emit events (no side effects), or handlers with `findOne({ where: { jobKey } })` dedup check at the top.
- **Confirm:** Read the handler; if side effects can repeat on retry, it's a violation.
- **Severity:** warning

---

## BE-QUEUE-002 — Use pg-boss not BullMQ

**What to check:** No BullMQ / @nestjs/bull imports.

**Scan:**
```
Grep pattern: "@nestjs/(bull|bullmq)|from ['\"]bullmq['\"]|from ['\"]bull['\"]"
     path:    __BE_DIR__
     output_mode: content
```
Also:
```
Grep pattern: "\"@nestjs/(bull|bullmq)\""
     path:    __BE_DIR__/package.json
     output_mode: content
```

- **True positive:** Any import of `@nestjs/bull`, `@nestjs/bullmq`, `bull`, or `bullmq`.
- **False positive:** Comments / docs mentioning BullMQ for comparison purposes (rare).
- **Confirm:** No confirmation needed for production imports.
- **Severity:** error (unless an ADR justifies)

---

## BE-QUEUE-003 — Job failures logged at WARN+

**What to check:** `.work()` handler catch blocks log at Warning or Error severity.

**Scan:**
```
Grep pattern: "\\.work\\s*\\([\\s\\S]{0,500}catch\\s*\\([^)]*\\)[\\s\\S]{0,200}logger\\.(debug|info)\\("
     multiline: true
     path:    __BE_DIR__/src
     output_mode: content
```

- **True positive:** `.work('...', async (job) => { try { ... } catch (e) { logger.debug('failed', e); } })`.
- **False positive:** Info-level logs that also re-throw (the throw will be caught upstream and logged at Error).
- **Confirm:** Check if the error is re-thrown after logging; if yes, info-level is acceptable (the upstream handler will log appropriately).
- **Severity:** warning
