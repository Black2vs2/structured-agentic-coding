# Scan Playbook: API & Swagger

Category: `api` | Rules: BE-API-001 through BE-API-004

---

## BE-API-001 — Swagger env-gated

**What to check:** `SwaggerModule.setup()` must be conditional on environment (not always on in production).

**Scan:**
```
Grep pattern: "SwaggerModule\\.setup"
     path:    ./src
     output_mode: content
     -B:      5
     -A:      5
```

- **True positive:** `SwaggerModule.setup('api/docs', app, document)` without any surrounding `if (...)` check for `NODE_ENV` or `ENABLE_SWAGGER`.
- **False positive:** `if (process.env.ENABLE_SWAGGER === 'true' || process.env.NODE_ENV !== 'production') SwaggerModule.setup(...)` — gated correctly.
- **Confirm:** Read the surrounding block for the env gate.
- **Severity:** error

---

## BE-API-002 — REST controllers thin

**What to check:** REST controllers (`@Controller`) delegate to services — no business logic, validation, or DB access inline.

**Scan:**
```
Grep pattern: "@Controller\\("
     path:    ./src
     output_mode: content
     -A:      40
```
For each match, inspect the controller body. Flag direct `this.repo.`, `this.dataSource.`, or multi-step business logic inline.

- **True positive:** A controller method that calls `userRepo.find` directly and runs a conditional update.
- **False positive:** Controllers that only delegate (`return this.userService.create(input)`) or raise `@Public()` health checks.
- **Confirm:** Read method body — anything beyond `return this.service.method(args)` is suspect.
- **Severity:** warning

---

## BE-API-003 — Health check convention

**What to check:** A health endpoint at `GET /api/ping` exists and returns a minimal JSON body.

**Scan:**
```
Grep pattern: "@Get\\(['\"]?/?ping['\"]?\\)"
     path:    ./src
     output_mode: content
     -B:      3
     -A:      10
```

- **True positive:** No `/ping` endpoint anywhere, or a `/ping` that returns a complex object.
- **False positive:** Alternative names (`/health`, `/healthz`) — flag with an info-level suggestion to align with convention.
- **Confirm:** Read the handler; verify it's `Get('/ping')` under a controller with `/api` prefix, returning `{ ok: true }` or similar.
- **Severity:** info (convention nudge)

---

## BE-API-004 — No business logic in controllers

**What to check:** Controllers must not import entity classes or repository tokens directly.

**Scan:**
```
Grep pattern: "import.*from.*entity"
     path:    ./src/**/*.controller.ts
     output_mode: content
```
Also:
```
Grep pattern: "@InjectRepository\\("
     path:    ./src/**/*.controller.ts
     output_mode: content
```

- **True positive:** Controller importing an entity or injecting a repository directly.
- **False positive:** Controller importing a DTO (DTOs live outside `entity/` — importing the DTO is fine).
- **Confirm:** Read the import — if it's from `./entity/` or contains `Entity` as a class name, it's a violation.
- **Severity:** warning
