<!--
Profile CLAUDE.md overlay for refine-nestjs-query-fe. Appended to
CLAUDE.md after the base fragments so Refine/GraphQL/shadcn specifics
live with the profile.
-->

### Refine.dev framework

- App composition (`src/App.tsx`) wraps `<Refine>` with providers: `dataProvider` (`@refinedev/nestjs-query`), `authProvider` (Firebase), `routerProvider` (`@refinedev/react-router`), `i18nProvider`, `accessControlProvider`, `notificationProvider`. Do NOT bypass these for ad-hoc fetch calls.
- Resources are registered in `<Refine resources={[...]}>`. Each resource has its own directory under `src/resources/<name>/` with pages + hooks + queries.
- Use `useTranslation` from `@refinedev/core`, NEVER from `react-i18next` directly. Translation keys follow `pages.<resource>.<section>.<key>`.

### GraphQL & codegen

- Operations stored as **inline** `` gql`...` `` template tags in `.ts` / `.tsx` files — no standalone `.graphql` files.
- Codegen command: `__GRAPHQL_CODEGEN__`. Schema source configured in `graphql.config.ts` (also tracked as `GRAPHQL_SCHEMA_SRC` in the scaffold manifest; accepts a URL for remote introspection or a local file path).
- Auto-generated types land in `src/graphql/schema.types.ts` and `src/graphql/types.ts`. **Never hand-edit** — regen via `__GRAPHQL_CODEGEN__`.
- `vite-plugin-graphql-codegen` runs codegen automatically on dev server start and on operation file watch.

### Forms & validation

- `react-hook-form` + `@hookform/resolvers/zod`. **Always import Zod from `zod/v4`**, never from `zod` (Zod v4 is a separate import path).
- Custom error mapping lives in `src/lib/form-validation.ts` and wires i18n keys through the Zod error map.

### Styling

- shadcn/ui (style "new-york") + Radix primitives + Tailwind 4 via `@tailwindcss/vite`. CSS variables for brand colors are declared in `src/index.css` — use those, do not hardcode hex values in components.
- Emotion is present for legacy reasons but secondary — prefer Tailwind + shadcn patterns.

### Environment & protected paths

- Env vars: only `import.meta.env.VITE_*`, typed in `src/vite-env.d.ts`. No `process.env.*`.
- Protected (never hand-edit): `src/graphql/schema.types.ts`, `src/graphql/types.ts` (auto-generated), `patches/` (dependency patches for Refine).

### Commands

- Dev: `__FE_SERVE__`
- Build (prod): `__FE_BUILD__`
- Build (staging): `__FE_BUILD_STAGE__`
- Typecheck: `__FE_TYPECHECK__`
- Lint (check): `__FE_LINT__`
- Lint (autofix): `__FE_LINT_FIX__`
- Format: `__FE_FORMAT__`
- GraphQL codegen: `__GRAPHQL_CODEGEN__`
- Tests (Vitest): `__FE_TEST__`
- E2E tests: `__E2E_CMD__`
