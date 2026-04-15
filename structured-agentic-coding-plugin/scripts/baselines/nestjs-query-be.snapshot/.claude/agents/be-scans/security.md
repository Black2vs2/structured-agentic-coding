# Scan Playbook: Security

Category: `security` | Rules: BE-SEC-001 through BE-SEC-005

---

## BE-SEC-001 — Helmet configured

**What to check:** `app.use(helmet(...))` (or equivalent) must be present in `src/main.ts` before any route registration.

**Scan:**
```
Grep pattern: "helmet"
     path:    ./src/main.ts
     output_mode: content
```

- **True positive:** No match — Helmet missing entirely.
- **False positive:** None — Helmet is mandatory.
- **Confirm:** Read `main.ts`; Helmet registration must be before `app.listen()`.
- **Severity:** error

---

## BE-SEC-002 — Throttler global

**What to check:** `ThrottlerModule` is imported in `AppModule` with a global rate limit.

**Scan:**
```
Grep pattern: "ThrottlerModule\\.forRoot"
     path:    ./src/app.module.ts
     output_mode: content
     -A:      10
```

- **True positive:** No ThrottlerModule in AppModule imports, or forRoot with `ttl: 0` / unbounded config.
- **False positive:** `ttl: 60000, limit: 10` or similar reasonable values.
- **Confirm:** Read the forRoot config.
- **Severity:** warning

Also check for per-endpoint overrides without justification:
```
Grep pattern: "@Throttle\\("
     path:    ./src
     output_mode: content
     -B:      3
```
Flag overrides without a comment.

---

## BE-SEC-003 — Turnstile on public mutations

**What to check:** Public (unauthenticated) mutations are protected by `TurnstileGuard`.

**Scan:**
```
Grep pattern: "@Public\\(\\)|@Mutation.*(?:waitlist|contact|signup|register)"
     path:    ./src
     output_mode: content
     -A:      5
```
For each public mutation match, verify `TurnstileGuard` is applied (either via `@UseGuards(TurnstileGuard)` for non-global cases or via a dedicated public-endpoint guard).

- **True positive:** Public waitlist/contact mutation without Turnstile.
- **False positive:** Public mutations behind a different bot-protection mechanism (rare — flag for confirmation).
- **Confirm:** Trace guard chain; if Turnstile or equivalent isn't applied, it's a violation.
- **Severity:** error

---

## BE-SEC-004 — No hardcoded secrets

**What to check:** No literal secrets (API keys, tokens, connection strings) in source files.

**Scan:**
```
Grep pattern: "(AKIA[0-9A-Z]{16}|sk_live_[a-zA-Z0-9]+|Bearer [a-zA-Z0-9_.-]{40,}|postgres://[^\\s]+:[^@\\s]+@)"
     path:    ./src
     output_mode: content
```
Also:
```
Grep pattern: "(api_?key|secret|password|token)\\s*[=:]\\s*['\"`][a-zA-Z0-9_.+\\-]{16,}['\"`]"
     -i:      true
     path:    ./src
     output_mode: content
```

- **True positive:** Literal AWS key, Stripe key, or long token/password in source.
- **False positive:** Test fixtures using clearly-fake values (`'test-key'`, `'fake-token'`). Env var names in `process.env.*` strings — those are labels, not values.
- **Confirm:** Read the match; if the value looks like a real secret, it's a violation regardless of file.
- **Severity:** error

---

## BE-SEC-005 — CSP allows introspection only in dev

**What to check:** Helmet CSP config allowing inline scripts / Apollo introspection must be gated to non-production.

**Scan:**
```
Grep pattern: "contentSecurityPolicy[\\s\\S]{0,500}(unsafe-inline|unsafe-eval)"
     multiline: true
     path:    ./src
     output_mode: content
     -B:      5
```

- **True positive:** CSP with `unsafe-inline` or `unsafe-eval` without an env check.
- **False positive:** CSP gated by `if (process.env.NODE_ENV !== 'production')`.
- **Confirm:** Read the surrounding block for the env gate.
- **Severity:** warning
