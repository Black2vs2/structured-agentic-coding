<!--
Profile CLAUDE.md overlay for angular-dotnet. Appended to CLAUDE.md after
the base fragments so profile-specific commands (database, migrations,
openapi-sync) don't bleed into the general _be-section template.
-->

### .NET / EF Core specifics

- Database (local Postgres): `__DB_START__`
- EF Core migration: `__MIGRATION__`
- OpenAPI → frontend client sync: `/openapi-sync` (available only when scaffolded fullstack)
