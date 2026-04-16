# Scan Playbook: TypeORM & Migrations

Category: `typeorm` | Rules: BE-TYPEORM-001 through BE-TYPEORM-008

---

## BE-TYPEORM-001 — No synchronize: true

**What to check:** `synchronize: true` must not appear in any DataSource, TypeOrmModule config, or env-driven override.

**Scan:**
```
Grep pattern: "synchronize\\s*:\\s*true"
     path:    ./src
     output_mode: content
```
Also check:
```
Grep pattern: "synchronize\\s*:\\s*true"
     path:    ./database
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
     path:    ./database/migrations
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
     path:    ./database/migrations
     output_mode: content
```
Also:
```
Grep pattern: "async down[\\s\\S]*?throw new"
     multiline: true
     path:    ./database/migrations
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
     path:    ./src
     output_mode: content
```
Also:
```
Grep pattern: "new \\w+Entity\\s*\\(\\s*\\{\\s*id\\s*:"
     path:    ./src
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
     path:    ./src/**/entity
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
     path:    ./src
     output_mode: content
```

- **True positive:** `await dataSource.query('UPDATE users SET ...')`.
- **False positive:** `await dataSource.query('SELECT ...')` — read-only analytics are acceptable with justification comment.
- **Confirm:** Verify operation is a mutation; if it's read-only, look for a justification comment above the call.
- **Severity:** error (mutations), info (reads without comment)

---

## BE-TYPEORM-007 — Entity change requires matched migration

**What to check:** Any diff that modifies entity files must include a new migration file.

**Scan:**
- Changed entity files: `git diff --name-only <base>..HEAD | grep -E '^src/.*entity/.*\.ts$'`
- If non-empty, require: `git diff --diff-filter=A --name-only <base>..HEAD | grep -E '^database/migrations/.*\.ts$'` to also be non-empty.
- **False positive:** Entity edit that doesn't touch schema surface (JSDoc comments only, import reorder, formatting). Inspect the patch — if only whitespace/comments/imports changed, OK. Metadata-only `@Column` changes (enum mapping, eager, cascade) that don't alter the physical DB schema also OK.
- **Confirm:** Check the entity diff for column/relation/index/enum changes vs. non-schema noise.
- **Severity:** error

---

## BE-TYPEORM-008 — Bidirectional relations

**What to check:** Every `@ManyToOne` on a child entity must have a matching `@OneToMany` on the parent entity, unless the child declaration has an inline `// Intentionally one-sided: <reason>` comment.

**Scan:**
```
Grep pattern: "@ManyToOne\\("
     path:    ./src/**/entity
     output_mode: content
     -B:      3
```
For each match:
1. Read the 3 lines above the `@ManyToOne`. If they include `// Intentionally one-sided:`, accept and move on.
2. Identify the target parent entity class from the arrow (e.g., `() => PartnerEntity`).
3. Open the parent entity file (`src/<feature>/entity/<parent>.entity.ts`) and search for `@OneToMany(() => <ChildEntity>`.
4. If no inverse is declared, this is a violation.
5. When the inverse exists, also spot-check that the parent DTO exposes it via `@FilterableOffsetConnection(...)` if a parent→child query makes domain sense (info-level only — not a hard rule).

- **True positive:** `LocationEntity.partner: PartnerEntity` declared via `@ManyToOne`; `PartnerEntity` has no `@OneToMany(() => LocationEntity, ...)` and no justification comment.
- **False positive:** Parent has the inverse. OR the child declaration has `// Intentionally one-sided: <reason>` on the line(s) directly above.
- **Confirm:** Open both files; verify the inverse is present/absent and read the reason comment if any.
- **Severity:** warning
