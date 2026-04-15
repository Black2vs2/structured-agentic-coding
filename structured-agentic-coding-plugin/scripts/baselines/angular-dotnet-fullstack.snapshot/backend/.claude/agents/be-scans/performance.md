# Scan Playbook: Performance

Category: `performance` | Rules: BE-PERF-001 through BE-PERF-003

---

## BE-PERF-001 — Bulk ops via EF Core 7+

**What to check:** Flag load-iterate-save patterns when `ExecuteUpdateAsync` or `ExecuteDeleteAsync` would work instead. Exception: audit trail needed -> load-save is OK if justified with a comment.

**Scan 1 — Find load-iterate-save patterns:**
```
Grep pattern: "foreach.*await.*SaveChangesAsync"
     path:    backend/src/App.Application
     output_mode: content
     multiline: true
```

If that's too broad, use a two-step approach:

**Scan 1a — Find foreach loops in handlers:**
```
Grep pattern: "foreach\s*\(var \w+ in"
     path:    backend/src/App.Application
     output_mode: content
```

**Scan 1b — Find SaveChangesAsync calls:**
```
Grep pattern: "SaveChangesAsync"
     path:    backend/src/App.Application
     output_mode: files_with_matches
```
- **Interpretation:** Files that have BOTH a foreach loop AND SaveChangesAsync may be doing load-iterate-save. Cross-reference the two result sets.
- **Confirm:** Read files that appear in both results to check if the SaveChangesAsync is inside or after a foreach loop that modifies loaded entities one at a time.

**Scan 2 — Check if ExecuteUpdateAsync/ExecuteDeleteAsync is ever used:**
```
Grep pattern: "Execute(Update|Delete)Async"
     path:    backend/src/App.Application
     output_mode: content
```
- **Interpretation:** If never used, note as a general recommendation. If used in some places but not others, flag the inconsistency.

- **True positive:** Loading 100 entities in a loop, modifying each, then calling SaveChangesAsync — should use `ExecuteUpdateAsync`
- **False positive:** Loading entities that need audit trail (CreatedBy/UpdatedBy stamps from interceptor) — load-save is required for audit. Comment should explain.
- **False positive:** Loading a small fixed set of entities (e.g., reorder 5 items) — bulk ops overkill
- **Severity:** info

---

## BE-PERF-002 — Database index awareness

**What to check:** Suggest indexes for frequently filtered/sorted columns on large tables that lack explicit index configuration.

**Scan 1 — Find Where clauses on large tables:**
```
Grep pattern: "\.(\w+)\s*\.\s*Where\("
     path:    backend/src/App.Application
     output_mode: content
     context: 2
```
- **Interpretation:** Extract the property being filtered. Then check if an index exists for that property.

**Scan 2 — Find OrderBy on large tables:**
```
Grep pattern: "\.(\w+)\s*.*OrderBy"
     path:    backend/src/App.Application
     output_mode: content
```

**Scan 3 — Check existing indexes:**
```
Grep pattern: "HasIndex|\.HasAlternateKey"
     path:    backend/src/App.Migrations/Data
     output_mode: content
```
- **Interpretation:** Cross-reference: columns frequently used in Where/OrderBy on large tables should have corresponding HasIndex in configurations. Missing indexes are findings.
- **True positive:** `db.Events.Where(e => e.ParentId == id).OrderBy(e => e.Timestamp)` with no index on `ParentId` or `Timestamp`
- **False positive:** FK columns that EF Core automatically indexes (convention-based)
- **Confirm:** EF Core creates indexes automatically for FK properties. Only flag non-FK columns that are frequently filtered/sorted. Read the configuration file to verify.
- **Severity:** info

---

## BE-PERF-003 — Select projections

**What to check:** Query handlers that load full entities but map to a subset DTO should use `.Select(e => new Dto(...))` projection instead.

**Scan 1 — Find query handlers with entity-to-DTO mapping:**
```
Grep pattern: "new \w+Dto\s*(\{|\()"
     path:    backend/src/App.Application
     output_mode: files_with_matches
     glob:    "**/Queries/**/*.cs"
```

**Scan 2 — Check if they use Select projection:**
```
Grep pattern: "\.Select\("
     path:    backend/src/App.Application
     output_mode: files_with_matches
     glob:    "**/Queries/**/*.cs"
```
- **Interpretation:** Files in scan 1 (manual DTO mapping) that are NOT in scan 2 (no Select projection) are candidates for optimization. They might be loading full entities and then mapping in memory.
- **Confirm:** Read the handler to verify the pattern:
  - Bad: `var entity = await db.Entities.FirstOrDefaultAsync(...); return new EntityDto { Name = entity.Name, ... };` — loading full entity, mapping in memory
  - Good: `return await db.Entities.Where(...).Select(c => new EntityDto { Name = c.Name }).FirstOrDefaultAsync();` — projection at DB level
- **True positive:** Full entity load followed by manual property mapping to DTO
- **False positive:** Handlers that need the full entity for complex logic before mapping
- **Severity:** info
