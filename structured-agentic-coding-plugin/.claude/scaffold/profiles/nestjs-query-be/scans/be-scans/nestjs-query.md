# Scan Playbook: nestjs-query

Category: `nestjs-query` | Rules: BE-QUERY-001 through BE-QUERY-015

---

## BE-QUERY-001 — @FilterableField on DTO fields

**What to check:** Every queryable field on an `@ObjectType()` DTO uses `@FilterableField()` (not `@Field()`).

**Scan:**
```
Grep pattern: "@Field\\("
     path:    __BE_DIR__/src/**/dto
     output_mode: content
```

- **True positive:** `@Field() name: string;` inside a class annotated with `@ObjectType()`.
- **False positive:** `@Field()` inside `@InputType()` DTOs (input types use @Field, not @FilterableField). Also `@AdminOnlyField()` decorated fields.
- **Confirm:** Read the class — if decorated with `@ObjectType()`, @Field should be @FilterableField unless @AdminOnlyField is also applied.
- **Severity:** warning

---

## BE-QUERY-002 — GraphQL schema not hand-edited

**What to check:** Nobody edits `__GRAPHQL_SCHEMA_OUT__` by hand; it's auto-regenerated.

**Scan:**
```
Bash: git log --oneline -- __GRAPHQL_SCHEMA_OUT__ 2>/dev/null | head -20
```
If available, look at recent commits touching the schema file: each should come alongside resolver/DTO changes. Direct edits without code changes are suspicious.

Also:
```
Grep pattern: "# This file was automatically generated"
     path:    __GRAPHQL_SCHEMA_OUT__
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
     path:    __BE_DIR__/src/**/service
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
     path:    __BE_DIR__/src
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

---

## BE-QUERY-006 — Override QueryService provider

**What to check:** Every feature module that defines a custom service extending `TypeOrmQueryService` must provide the `getQueryServiceToken(Entity)` mapping.

**Scan:**
```
Grep pattern: "extends TypeOrmQueryService"
     path:    __BE_DIR__/src
     output_mode: files_with_matches
```
For each file, open the sibling `*.module.ts` and verify `{ provide: getQueryServiceToken(XxxEntity), useExisting: XxxService }` appears in providers.

- **True positive:** Service extends TypeOrmQueryService; module's providers array has the service but no getQueryServiceToken mapping.
- **False positive:** None — override is mandatory.
- **Severity:** error

---

## BE-QUERY-007 — Wrapper input types for custom mutations

**What to check:** Resolvers that disable a built-in CRUD endpoint AND define a custom mutation must use the CreateOneInputType/UpdateOneInputType/DeleteOneInputType wrapper.

**Scan:**
```
Grep pattern: "(create|update|delete)\\s*:\\s*\\{\\s*disabled\\s*:\\s*true"
     path:    __BE_DIR__/src/**/resolver
     output_mode: content
     -A:      20
```
For each match, find the custom @Mutation method and check that its @Args('input') type extends `CreateOneInputType(...)` / `UpdateOneInputType(...)` / `DeleteOneInputType(...)`.

- **True positive:** `create: { disabled: true }` + custom `@Mutation` accepting `@Args('input') input: XxxCreateInputDTO` (flat, not wrapped).
- **False positive:** Built-in CRUD enabled (wrapper auto-generated by nestjs-query).
- **Severity:** error

---

## BE-QUERY-008 — Use `dtos` not `resolvers`

**What to check:** `NestjsQueryGraphQLModule.forFeature(...)` must use the `dtos` key, not `resolvers`.

**Scan:**
```
Grep pattern: "NestjsQueryGraphQLModule\\.forFeature\\([^)]*resolvers\\s*:"
     multiline: true
     path:    __BE_DIR__/src
     output_mode: content
```

- **True positive:** `NestjsQueryGraphQLModule.forFeature({ resolvers: [...] })`.
- **False positive:** None.
- **Severity:** error

---

## BE-QUERY-009 — Import owning module, not foreign entities

**What to check:** A feature module must not register `TypeOrmModule.forFeature([OtherDomainEntity])` for an entity owned by another module.

**Scan:**
```
Grep pattern: "TypeOrmModule\\.forFeature\\(\\[([^\\]]+)\\]\\)"
     path:    __BE_DIR__/src/**/*.module.ts
     output_mode: content
```
For each match, verify every entity listed belongs to the same directory as the module file. Flag cross-domain entities.

- **True positive:** `src/users/users.module.ts` registers `TypeOrmModule.forFeature([PartnerEntity])`.
- **False positive:** Registering own entities (same feature directory) — expected.
- **Confirm:** Read the import paths; entities from `src/<other-feature>/entity/` are violations.
- **Severity:** warning

---

## BE-QUERY-010 — No pattern-blocking scalar resolvers on FilterableField

**What to check:** Text fields (name, email, phone, description) must use `String` in `@FilterableField`, not `EmailAddressResolver` or `PhoneNumberResolver`.

**Scan:**
```
Grep pattern: "@FilterableField\\(\\(\\)\\s*=>\\s*(EmailAddressResolver|PhoneNumberResolver)"
     path:    __BE_DIR__/src/**/dto
     output_mode: content
```

- **True positive:** `@FilterableField(() => EmailAddressResolver) email: string;`.
- **False positive:** None.
- **Severity:** warning

---

## BE-QUERY-011 — @Resolver uses arrow function

**What to check:** `@Resolver()` decorator argument must be an arrow function returning the DTO class.

**Scan:**
```
Grep pattern: "@Resolver\\(\\s*[A-Z]\\w+\\s*\\)"
     path:    __BE_DIR__/src/**/resolver
     output_mode: content
```

- **True positive:** `@Resolver(OrderDTO)` — bare class reference.
- **False positive:** `@Resolver(() => OrderDTO)` — correct arrow form.
- **Severity:** error

---

## BE-QUERY-012 — Custom mutations return DTO not Entity

**What to check:** Custom @Mutation methods in resolvers using an assembler must return `Promise<FeatureDTO>`, not `Promise<FeatureEntity>`.

**Scan:**
```
Grep pattern: "@Mutation[\\s\\S]{0,100}Promise<\\w+Entity>"
     multiline: true
     path:    __BE_DIR__/src/**/resolver
     output_mode: content
```

- **True positive:** `async createOneFoo(...): Promise<FooEntity> {`.
- **False positive:** Resolver has no assembler (1:1 DTO/entity with no relations to translate) — but prefer DTO return anyway for consistency.
- **Confirm:** Check the resolver imports — if `assembler.convertToDTO()` exists in the module, this is a violation.
- **Severity:** warning

---

## BE-QUERY-013 — Single `input` arg on mutations

**What to check:** Every `@Mutation` must take exactly one `@Args('input')` argument.

**Scan:**
```
Grep pattern: "@Mutation[\\s\\S]{0,300}@Args\\("
     multiline: true
     path:    __BE_DIR__/src/**/resolver
     output_mode: content
```
Count the `@Args(...)` occurrences per mutation body. Flag those with more than one.

- **True positive:** `async deleteOneFoo(@Args('id') id: string, @Args('reason') reason: string) {`.
- **False positive:** Single `@Args('input')` with a wrapper InputType.
- **Severity:** error

---

## BE-QUERY-014 — CRUDResolver must specify CreateDTOClass/UpdateDTOClass

**What to check:** CRUDResolver calls that do NOT disable create or update must pass `CreateDTOClass` / `UpdateDTOClass` explicitly.

**Scan:**
```
Grep pattern: "CRUDResolver\\("
     path:    __BE_DIR__/src/**/resolver
     output_mode: content
     -A:      15
```
For each match, check if create/update are disabled. If not, verify `CreateDTOClass` and `UpdateDTOClass` are present in the options object.

- **True positive:** `CRUDResolver(OrderDTO, { ... })` without `CreateDTOClass` and create is not disabled.
- **False positive:** CRUDResolver with `create: { disabled: true }, update: { disabled: true }` — no DTO classes needed.
- **Confirm:** Read the full options object; the module-level `dtos[].CreateDTOClass` does NOT substitute for this.
- **Severity:** error

---

## BE-QUERY-015 — Wrapper InputType classes for custom mutation readiness

**What to check:** Every create input file should define a companion `CreateOneXxxInput` class extending `CreateOneInputType(...)`. Same for update and delete.

**Scan:**
```
Grep pattern: "export class \\w+CreateInputDTO"
     path:    __BE_DIR__/src/**/dto
     output_mode: files_with_matches
```
For each create input file, check for a companion `CreateOneXxxInput` class:
```
Grep pattern: "extends CreateOneInputType"
     path:    <same file>
     output_mode: content
```

- **True positive:** File defines `OrderCreateInputDTO` but no `CreateOneOrderInput extends CreateOneInputType(...)`.
- **False positive:** None — convention requires wrapper types.
- **Confirm:** Check the file exports both classes.
- **Severity:** info
