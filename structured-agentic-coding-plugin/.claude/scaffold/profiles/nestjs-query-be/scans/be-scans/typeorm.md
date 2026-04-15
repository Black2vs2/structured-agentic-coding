# Scan Playbook: TypeORM & Migrations

Category: `typeorm` | Rules: BE-TYPEORM-001 through BE-TYPEORM-006

---

## BE-TYPEORM-001 — No synchronize: true

**What to check:** `synchronize: true` must not appear in any DataSource, TypeOrmModule config, or env-driven override.

**Scan:**
```
Grep pattern: "synchronize\\s*:\\s*true"
     path:    __BE_DIR__/src
     output_mode: content
```
Also check:
```
Grep pattern: "synchronize\\s*:\\s*true"
     path:    __BE_DIR__/database
     output_mode: content
```

- **True positive:** `TypeOrmModule.forRoot({ ...config, synchronize: true })` anywhere.
- **False positive:** None — synchronize: false or omission is the only safe state.
- **Confirm:** No confirmation needed.
- **Severity:** error

---

## BE-TYPEORM-002 — Descriptive migration names

**What to check:** Migration class names should describe the change. Generic names (`Migration1234`, `Update`, `Fix`, `Change`) are violations.

**Scan:**
```
Grep pattern: "^export class (Migration|Update|Fix|Change)\\d*"
     path:    __BE_DIR__/database/migrations
     output_mode: content
```

- **True positive:** `export class Migration1678901234567 implements MigrationInterface`.
- **False positive:** None — generics are always bad names.
- **Confirm:** No confirmation needed.
- **Severity:** warning

---

## BE-TYPEORM-003 — down() reverses up()

**What to check:** Every migration's `down()` must reverse what `up()` does. Empty bodies and throws are violations.

**Scan:**
```
Grep pattern: "async down\\([^)]*\\)\\s*:\\s*Promise<[^>]*>\\s*\\{\\s*\\}"
     path:    __BE_DIR__/database/migrations
     output_mode: content
```
Also:
```
Grep pattern: "async down[\\s\\S]*?throw new"
     multiline: true
     path:    __BE_DIR__/database/migrations
     output_mode: content
```

- **True positive:** `async down(queryRunner: QueryRunner): Promise<void> {}` (empty) or `throw new Error('not supported')`.
- **False positive:** `down()` that legitimately cannot reverse (e.g., dropped data) must have a comment explaining why — read the file to confirm.
- **Confirm:** Read the migration; verify the up() operations each have a reverse or an explicit comment.
- **Severity:** error (empty/throw), warning (partial reverse)

---

## BE-TYPEORM-004 — No explicit Id assignment

**What to check:** Don't assign `id` manually before `save()`.

**Scan:**
```
Grep pattern: "\\.id\\s*=\\s*(uuid|v4|randomUUID|Guid)"
     path:    __BE_DIR__/src
     output_mode: content
```
Also:
```
Grep pattern: "new \\w+Entity\\s*\\(\\s*\\{\\s*id\\s*:"
     path:    __BE_DIR__/src
     output_mode: content
```

- **True positive:** `entity.id = v4();` or `new OrderEntity({ id: '...', ... })` before save.
- **False positive:** Assigning to a DTO (not an entity) — these are test fixtures, OK.
- **Confirm:** Verify the target is an entity (decorated with `@Entity`), not a DTO.
- **Severity:** warning

---

## BE-TYPEORM-005 — FK with explicit onDelete

**What to check:** `@ManyToOne`, `@OneToMany`, `@OneToOne` relations must specify `onDelete` explicitly.

**Scan:**
```
Grep pattern: "@(ManyToOne|OneToMany|OneToOne|JoinColumn)\\("
     path:    __BE_DIR__/src/**/entity
     output_mode: content
     -A:      5
```
Flag any match whose relation options object omits `onDelete`.

- **True positive:** `@ManyToOne(() => User, { eager: false })` — no onDelete.
- **False positive:** `@ManyToOne(() => User, { onDelete: 'RESTRICT', eager: false })` — explicit, OK.
- **Confirm:** Read each match's options; absence of onDelete key is the violation.
- **Severity:** warning

---

## BE-TYPEORM-006 — No raw SQL for mutations

**What to check:** `.query()` calls on DataSource or Repository performing INSERT/UPDATE/DELETE.

**Scan:**
```
Grep pattern: "\\.query\\s*\\(\\s*['\"`](INSERT|UPDATE|DELETE)"
     path:    __BE_DIR__/src
     output_mode: content
```

- **True positive:** `await dataSource.query('UPDATE users SET ...')`.
- **False positive:** `await dataSource.query('SELECT ...')` — read-only analytics are acceptable with justification comment.
- **Confirm:** Verify operation is a mutation; if it's read-only, look for a justification comment above the call.
- **Severity:** error (mutations), info (reads without comment)
