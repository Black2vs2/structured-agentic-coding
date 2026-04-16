# Scan Playbook: Entity & Domain Design

Category: `entity-design` | Rules: BE-ENTITY-001 through BE-ENTITY-006

---

## BE-ENTITY-001 — All entities inherit BaseEntity

**What to check:** Every entity class in the Domain layer must inherit `BaseEntity`. Flag entities that define their own `Id`, `CreatedAt`, `CreatedBy`, `UpdatedAt`, or `UpdatedBy` properties.

**Scan 1 — Find entity classes:**
```
Grep pattern: "public class \w+ "
     path:    backend/src/App.Domain/Entities
     output_mode: content
```

**Scan 2 — Check for redefined audit fields:**
```
Grep pattern: "(Guid|DateTime|string)\s+(Id|CreatedAt|CreatedBy|UpdatedAt|UpdatedBy)\s*\{"
     path:    backend/src/App.Domain/Entities
     output_mode: content
     glob:    "*.cs"
```
- **True positive:** `public Guid Id { get; set; }` in an entity that's NOT `BaseEntity.cs`
- **False positive:** The `BaseEntity.cs` file itself defining these properties — this is correct
- **Confirm:** If scan 2 finds matches, Read the file to check it's not BaseEntity.cs and that the class doesn't inherit BaseEntity.
- **Severity:** warning

---

## BE-ENTITY-002 — Rich domain model

**What to check:** Business logic (state transitions, validation) belongs on the entity. Flag handlers that directly mutate complex state instead of calling entity methods.

**Scan — Direct status mutation in handlers:**
```
Grep pattern: "\.(Status|InviteStatus|EvaluationStatus)\s*="
     path:    backend/src/App.Application
     output_mode: content
```
- **True positive:** `entity.Status = EntityStatus.Active;` in a handler — should use `entity.Activate()`
- **False positive:** Setting status during entity creation in a Create handler (e.g., `Status = EntityStatus.Draft` in object initializer) — typically acceptable
- **Confirm:** Read surrounding context (~5 lines before/after) to determine if it's creation (acceptable) or mutation of an existing entity (violation).
- **Severity:** warning

Note: This overlaps with BE-STATE-001. If you report it under one rule, skip the other to avoid duplicates.

---

## BE-ENTITY-003 — Enums stored as strings

**What to check:** All enum properties must use `HasConversion<string>()` in their EF configuration. Integer storage is a violation.

**Scan 1 — Find enum conversions:**
```
Grep pattern: "HasConversion"
     path:    backend/src/App.Migrations/Data
     output_mode: content
```

**Scan 2 — Find enum properties in entities:**
```
Grep pattern: "(Status|Type|Category|Seniority|Priority)\s+\w+"
     path:    backend/src/App.Domain/Entities
     output_mode: content
```
- **Interpretation:** Cross-reference: every enum property found in scan 2 must have a corresponding `HasConversion<string>()` in scan 1. Missing conversions are violations.
- **True positive:** Entity has `public MyEnum Type { get; set; }` but the configuration file has no `HasConversion<string>()` for that property
- **False positive:** Enum properties that DO have string conversion configured
- **Confirm:** Read the corresponding `*Configuration.cs` file if unsure whether conversion exists.
- **Severity:** warning

---

## BE-ENTITY-004 — Explicit foreign keys

**What to check:** Every navigation property must have a corresponding FK property declared on the entity.

**Scan 1 — Find navigation properties:**
```
Grep pattern: "public (virtual\s+)?\w+ \w+\s*\{" 
     path:    backend/src/App.Domain/Entities
     output_mode: content
```

**Approach:** This is best checked by reading entity files and their configurations together. Focus on entities with relationships.

**Scan 2 — Check for shadow FK warnings:**
```
Grep pattern: "HasForeignKey"
     path:    backend/src/App.Migrations/Data
     output_mode: content
```
- **Interpretation:** Each `HasForeignKey` in configs should reference a property that actually exists on the entity class. If there's a relationship defined in a config WITHOUT `HasForeignKey` or where the FK property doesn't exist on the entity, that indicates a shadow property.
- **Confirm:** Read entity files only for entities where you suspect missing FK properties.
- **Severity:** warning

---

## BE-ENTITY-005 — DeleteBehavior.Restrict default

**What to check:** Flag `DeleteBehavior.Cascade` or `DeleteBehavior.SetNull` unless there's a justification comment nearby.

**Scan:**
```
Grep pattern: "DeleteBehavior\.(Cascade|SetNull)"
     path:    backend/src/App.Migrations/Data
     output_mode: content
     context: 2
```
- **True positive:** `.OnDelete(DeleteBehavior.Cascade)` with no comment explaining why
- **False positive:** `.OnDelete(DeleteBehavior.Cascade) // cascade needed: child has no meaning without parent`
- **Confirm:** The Grep with context=2 should show surrounding lines. Check for a `//` comment on the same line or line above. If no comment, it's a violation.
- **Severity:** warning

---

## BE-ENTITY-006 — Suggest value objects

**What to check:** Flag raw `string` type for email, token, or branch properties on new or modified entities. Suggest creating value objects.

**Scan:**
```
Grep pattern: "string\??\s+(Email|Token|UniqueToken|BranchName|Branch)\s"
     path:    backend/src/App.Domain/Entities
     output_mode: content
```
- **True positive:** `public string Email { get; set; }` — raw string for email
- **False positive:** None for this codebase (no value objects exist yet)
- **Confirm:** No confirmation needed. Any match is a valid suggestion.
- **Severity:** info (suggestion, not a hard violation)
