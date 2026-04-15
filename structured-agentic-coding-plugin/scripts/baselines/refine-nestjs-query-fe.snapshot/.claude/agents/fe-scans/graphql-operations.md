# Scan Playbook: GraphQL Operations

Category: `graphql` | Rules: FE-GQL-001 through FE-GQL-005

---

## FE-GQL-001 — Inline gql tags (no .graphql files)

**What to check:** GraphQL operations live as inline `gql\`...\`` tags in `.ts`/`.tsx`, not as standalone `.graphql` / `.gql` files.

**Scan:**
```
Glob pattern: ./src/**/*.graphql
Glob pattern: ./src/**/*.gql
```
Any match is a violation.

- **True positive:** `src/resources/orders/orders.graphql`.
- **False positive:** None — `.graphql` files are not the project convention.
- **Confirm:** No confirmation needed.
- **Severity:** warning

---

## FE-GQL-002 — TypedDocumentNode imported from codegen output

**What to check:** Hooks using GraphQL operations consume the TypedDocumentNode exports generated in `src/graphql/types.ts`.

**Scan:**
```
Grep pattern: "useQuery\\s*\\(\\s*gql`|useMutation\\s*\\(\\s*gql`"
     path:    ./src
     output_mode: content
```
Hooks that inline a raw `gql` tag instead of passing a generated document are violations.

- **True positive:** `useQuery(gql\`query Foo { ... }\`)` without importing the generated `FooDocument`.
- **False positive:** Operations defined once in a `queries.ts` file and then imported as named exports — acceptable as long as codegen picks them up.
- **Confirm:** Read the hook call; if it lacks the typed document, check whether codegen generated one.
- **Severity:** warning

---

## FE-GQL-003 — Generated types never hand-edited

**What to check:** `src/graphql/types.ts` and `src/graphql/schema.types.ts` must be produced by codegen only.

**Scan:**
```
Bash: git log --oneline -- ./src/graphql/types.ts ./src/graphql/schema.types.ts 2>/dev/null | head -20
```
Look at recent commits. Each should include a corresponding change to a `gql` operation or `graphql.config.ts`.

- **True positive:** Commit touching only `src/graphql/*.ts` without a matching code or schema change.
- **False positive:** Codegen-driven changes.
- **Confirm:** If git is unavailable, check the codegen header comment is intact at the top of the files.
- **Severity:** error

---

## FE-GQL-004 — Codegen freshness before commit

**What to check:** PRs that modify inline `gql` tags must include regenerated `src/graphql/*.ts`.

**Scan:**
```
Bash: git diff --name-only origin/main...HEAD 2>/dev/null
```
If diff touches any `.ts`/`.tsx` with `gql\`` content but NOT `src/graphql/*.ts`, flag.

- **True positive:** A PR adds a new `gql\`query Foo { ... }\`` in `src/resources/orders/queries.ts` but doesn't re-generate types.
- **False positive:** The change was a formatting-only gql tweak — no regen needed.
- **Confirm:** Compare the change to whether new types would be needed.
- **Severity:** warning

---

## FE-GQL-005 — No anonymous operations

**What to check:** Every `gql` tag has a named operation.

**Scan:**
```
Grep pattern: "gql`\\s*(query|mutation|subscription)\\s*\\{"
     multiline: true
     path:    ./src
     output_mode: content
```
Matches represent anonymous operations (no name between the operation keyword and the opening brace).

- **True positive:** `gql\`query { orders { id } }\``
- **False positive:** Operations with names (`gql\`query GetOrders { orders { id } }\``) — no match.
- **Confirm:** No confirmation needed.
- **Severity:** warning
