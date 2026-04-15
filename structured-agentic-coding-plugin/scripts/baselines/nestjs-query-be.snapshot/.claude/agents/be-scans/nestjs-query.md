# Scan Playbook: nestjs-query

Category: `nestjs-query` | Rules: BE-QUERY-001 through BE-QUERY-005

---

## BE-QUERY-001 — @FilterableField on DTO fields

**What to check:** Every queryable field on an `@ObjectType()` DTO uses `@FilterableField()` (not `@Field()`).

**Scan:**
```
Grep pattern: "@Field\\("
     path:    ./src/**/dto
     output_mode: content
```

- **True positive:** `@Field() name: string;` inside a class annotated with `@ObjectType()`.
- **False positive:** `@Field()` inside `@InputType()` DTOs (input types use @Field, not @FilterableField). Also `@AdminOnlyField()` decorated fields.
- **Confirm:** Read the class — if decorated with `@ObjectType()`, @Field should be @FilterableField unless @AdminOnlyField is also applied.
- **Severity:** warning

---

## BE-QUERY-002 — GraphQL schema not hand-edited

**What to check:** Nobody edits `src/schema.gql` by hand; it's auto-regenerated.

**Scan:**
```
Bash: git log --oneline -- src/schema.gql 2>/dev/null | head -20
```
If available, look at recent commits touching the schema file: each should come alongside resolver/DTO changes. Direct edits without code changes are suspicious.

Also:
```
Grep pattern: "# This file was automatically generated"
     path:    src/schema.gql
     output_mode: content
```
If the generator header is missing, the file has been edited.

- **True positive:** Commit touching only the schema file with no corresponding resolver/DTO changes; missing generator header.
- **False positive:** Schema change accompanied by a resolver/DTO change in the same commit.
- **Confirm:** Compare the commit's file changes; manual edits to schema without code changes are always a violation.
- **Severity:** error

---

## BE-QUERY-003 — Service extends TypeOrmQueryService

**What to check:** Feature services used by `CRUDResolver` extend `TypeOrmQueryService<Entity>` with `@QueryService(Entity)` decorator.

**Scan:**
```
Grep pattern: "class \\w+Service(?!\\s+extends TypeOrmQueryService)"
     path:    ./src/**/service
     output_mode: content
```

- **True positive:** `class FooService { ... }` without extending TypeOrmQueryService in a module that uses CRUDResolver.
- **False positive:** Services used for side-effects only (not CRUD) legitimately don't extend TypeOrmQueryService.
- **Confirm:** Check if the sibling resolver extends CRUDResolver; if yes, service must extend TypeOrmQueryService.
- **Severity:** warning

---

## BE-QUERY-004 — PagingStrategies.OFFSET only

**What to check:** No use of CURSOR paging anywhere.

**Scan:**
```
Grep pattern: "PagingStrategies\\.(CURSOR|KEYSET)|CursorPaging"
     path:    ./src
     output_mode: content
```

- **True positive:** `pagingStrategy: PagingStrategies.CURSOR` in a resolver config.
- **False positive:** None — project standard is OFFSET.
- **Confirm:** No confirmation needed.
- **Severity:** error

---

## BE-QUERY-005 — Assembler required when DTO shape differs

**What to check:** If a DTO has different fields than the corresponding entity, an assembler must be registered.

**Scan:** This rule requires cross-file inspection (compare entity fields to DTO fields). Hard to detect via Grep alone.

**Approach:**
1. Use `sac-graph` or Glob to list `src/<feature>/dto/*.ts` and `src/<feature>/entity/*.ts`.
2. Spot-check features where DTO and entity names differ (e.g., `OrderDTO` vs `OrderEntity`).
3. Read both files; if field sets diverge (extra/missing/renamed), look for an assembler in `src/<feature>/assembler/`.
4. If no assembler exists and the shapes differ → violation.

- **True positive:** `OrderDTO` has a `totalFormatted` field not on `OrderEntity`, and no assembler exists.
- **False positive:** DTO and entity are 1:1; nestjs-query's default assembler handles it.
- **Confirm:** Field-by-field comparison between DTO and entity.
- **Severity:** warning
