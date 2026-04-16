<!--
Umbrella CLAUDE.md overlay for the angular-dotnet fullstack profile. Appended
to CLAUDE.md after the angular-fe and dotnet-be overlays. Contains only
cross-layer commands and conventions that span both sides.
-->

### Fullstack coordination (Angular + .NET)

- OpenAPI → frontend client sync: `/openapi-sync`
  Regenerates the TypeScript API client from the live backend spec. Requires both FE and BE to be scaffolded.
- End-to-end tests exercise both sides: `__E2E_CMD__`
