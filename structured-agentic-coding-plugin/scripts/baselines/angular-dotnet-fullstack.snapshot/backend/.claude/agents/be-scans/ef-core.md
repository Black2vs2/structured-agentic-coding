# Scan Playbook: Data Access & EF Core

Category: `ef-core` | Rules: BE-EF-001 through BE-EF-010

---

## BE-EF-001 — AsNoTracking for read-only queries

**What to check:** Query handlers that don't call `SaveChangesAsync` must use `.AsNoTracking()` on their queries.

**Scan 1 — Find query handler files:**
```
Grep pattern: "class \w+Handler.*IRequestHandler"
     path:    backend/src/App.Application
     output_mode: files_with_matches
     glob:    "**/Queries/**/*.cs"
```

**Scan 2 — Check for AsNoTracking usage:**
```
Grep pattern: "AsNoTracking"
     path:    backend/src/App.Application
     output_mode: files_with_matches
     glob:    "**/Queries/**/*.cs"
```

**Scan 3 — Check for SaveChangesAsync in queries (shouldn't exist):**
```
Grep pattern: "SaveChangesAsync"
     path:    backend/src/App.Application
     output_mode: files_with_matches
     glob:    "**/Queries/**/*.cs"
```

- **Interpretation:** Files in scan 1 that are NOT in scan 2 AND NOT in scan 3 are violations (query handlers without AsNoTracking that don't save).
- **True positive:** A query handler that does `db.Entities.Where(...).ToListAsync()` without `.AsNoTracking()`
- **False positive:** Query handlers that use `.Select()` projection (EF Core doesn't track projected results, so AsNoTracking is unnecessary but harmless). Also skip handlers that DO call SaveChangesAsync (they need tracking).
- **Confirm:** Read files that appear in scan 1 but not in scan 2 to verify they're doing entity queries (not just projections).
- **Severity:** info

---

## BE-EF-002 — Separate IEntityTypeConfiguration

**What to check:** `OnModelCreating` should only call `ApplyConfigurationsFromAssembly`. Flag inline `Entity<T>()` configuration calls.

**Scan:**
```
Grep pattern: "modelBuilder\.Entity<"
     path:    backend/src/App.Migrations/Data/AppDbContext.cs
     output_mode: content
```
- **True positive:** `modelBuilder.Entity<MyEntity>(e => { e.Property(...) });` inline in AppDbContext
- **False positive:** None — all configuration should be in separate `*Configuration.cs` files
- **Confirm:** No confirmation needed.
- **Severity:** warning

---

## BE-EF-003 — JSONB hybrid config

**What to check:** Typed C# classes should use `OwnsOne()/.ToJson()`. `Dictionary`/`JsonDocument` types can use `HasColumnType("jsonb")`.

**Scan 1 — Find JSON column configurations:**
```
Grep pattern: "ToJson|jsonb|HasColumnType.*json"
     path:    backend/src/App.Migrations/Data
     output_mode: content
     -i:      true
```

**Scan 2 — Find OwnsOne/OwnsMany:**
```
Grep pattern: "OwnsOne|OwnsMany"
     path:    backend/src/App.Migrations/Data
     output_mode: content
```
- **Interpretation:** Typed nested objects should use OwnsOne/OwnsMany + ToJson. Raw Dictionary/JsonDocument with HasColumnType("jsonb") is acceptable.
- **Confirm:** If you find `HasColumnType("jsonb")` on a typed property (not Dictionary/JsonDocument), Read the entity to check the property type.
- **Severity:** info

---

## BE-EF-004 — Flag raw SQL

**What to check:** Flag `FromSqlRaw`, `ExecuteSqlRaw`, `FromSqlInterpolated`, `ExecuteSqlInterpolated`. Higher severity for INSERT/UPDATE/DELETE.

**Scan:**
```
Grep pattern: "FromSqlRaw|ExecuteSqlRaw|FromSqlInterpolated|ExecuteSqlInterpolated"
     path:    backend/src
     output_mode: content
     context: 2
```
- **True positive:** Any match — raw SQL bypasses EF tracking and audit
- **False positive:** None
- **Confirm:** Check context lines for INSERT/UPDATE/DELETE keywords (escalate to warning severity) vs SELECT (info severity).
- **Severity:** info (SELECT) or warning (mutations)

---

## BE-EF-005 — Descriptive migration names

**What to check:** Migration file names should be descriptive. Flag generic names like `Migration1`, `Update`, `Fix`.

**Scan:**
```
Glob pattern: backend/src/App.Migrations/Migrations/2*.cs
```
- **Interpretation:** Check migration file names (after the timestamp prefix). Names like `AddEntityStacks`, `MultiAgentEvaluation` are good. Names like `Migration1`, `Update`, `Fix`, `Changes` are bad.
- **True positive:** `20260320_Fix.cs` or `20260320_Update.cs`
- **False positive:** `20260320_AddBranchNameToEntity.cs` — descriptive, correct
- **Confirm:** Just check the file names from Glob results. No need to read file contents.
- **Severity:** info

Also check that `Down()` method reverses `Up()`:
```
Grep pattern: "protected override void Down"
     path:    backend/src/App.Migrations/Migrations
     output_mode: content
     context: 3
     glob:    "2*.cs"
```
- **True positive:** `Down()` method with empty body or just `// no-op`
- **Confirm:** Only check the most recent 2-3 migrations to keep budget.

---

## BE-EF-006 — Audit interceptor not bypassed

**What to check:** Flag `ExecuteSql` INSERT/UPDATE statements. Flag direct ADO.NET writes. Flag removal of the audit interceptor.

**Scan 1 — ExecuteSql mutations:**
Already covered by BE-EF-004 scan. Reuse those results.

**Scan 2 — ADO.NET access:**
```
Grep pattern: "SqlConnection|SqlCommand|DbCommand|GetDbConnection"
     path:    backend/src
     output_mode: content
```
- **True positive:** `using var conn = db.Database.GetDbConnection();` followed by raw commands
- **False positive:** None in this codebase
- **Confirm:** No confirmation needed.
- **Severity:** warning

---

## BE-EF-007 — Remove unnecessary Includes

**What to check:** Every `.Include()` chain must be used downstream. Flag unused includes.

**Scan:**
```
Grep pattern: "\.Include\("
     path:    backend/src/App.Application
     output_mode: content
```
- **Interpretation:** For each Include match, you need to check if the included navigation property is accessed later in the handler. This requires reading the file.
- **Confirm:** Read each file with `.Include()` calls. Check if the included property is used in the subsequent code (mapping, condition, return). If the include loads data that's never accessed, it's a violation.
- **Priority:** Only check files with 3+ Include calls to stay within budget.
- **Severity:** info

---

## BE-EF-008 — Bounded queries on large tables

**What to check:** Flag unbounded `ToListAsync()` on large tables without `.Take()`, `.Skip()`, or pagination.

**Scan:**
```
Grep pattern: "\.ToListAsync\(\)"
     path:    backend/src/App.Application
     output_mode: content
```
- **True positive:** `db.Entities.Where(...).ToListAsync()` without any Take/Skip/pagination
- **False positive:** `db.Entities.Where(...).Take(100).ToListAsync()` — bounded, correct. Also queries on small tables are acceptable.
- **Confirm:** Read surrounding context to check for:
  1. Is there a `.Take()` or `.Skip()` before `.ToListAsync()`?
  2. Is the table small vs large?
  3. Is there a tight `.Where()` clause that effectively bounds the result (e.g., filtering by a specific FK)?
- **Severity:** warning

---

## BE-EF-009 — No explicit Id assignment for BaseEntity

**What to check:** Flag `Id = Guid.CreateVersion7()`, `Id = Guid.NewGuid()`, or any explicit Id assignment when creating entities that inherit BaseEntity.

**Scan:**
```
Grep pattern: "Id\s*=\s*Guid\.(CreateVersion7|NewGuid)"
     path:    backend/src/App.Application
     output_mode: content
```
- **True positive:** `Id = Guid.CreateVersion7()` in a `new Entity { ... }` initializer
- **False positive:** Assigning Id for a non-BaseEntity type, or for DTOs/records
- **Confirm:** Read the surrounding code to verify the assignment is on an entity that inherits BaseEntity. Check the entity definition — use `find_symbol` or Grep for `BaseEntity` to confirm inheritance.
- **Severity:** warning

---

## BE-EF-010 — Use navigation properties for child entity creation

**What to check:** When creating parent+children, use navigation collection property (e.g., `Children = [..items]`). Flag manual FK assignment + separate `db.ChildSet.Add()`.

**Scan 1 — Find separate Add calls:**
```
Grep pattern: "db\.\w+\.Add\("
     path:    backend/src/App.Application
     output_mode: content
```

**Scan 2 — Find manual FK assignment:**
```
Grep pattern: "\w+Id\s*=\s*(parent|entity)\."
     path:    backend/src/App.Application
     output_mode: content
     -i:      true
```
- **True positive:** `newChild.ParentId = parent.Id; db.Children.Add(newChild);` — should instead be `parent.Children = [..items]`
- **False positive:** `db.Entities.Add(entity)` — adding a root entity to its own DbSet is correct
- **Confirm:** Read surrounding code to determine if a child entity is being created separately instead of via the parent's navigation property.
- **Severity:** info
