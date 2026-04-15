# Scan Playbook: Validation & Errors

Category: `validation` | Rules: BE-VAL-001 through BE-VAL-005

---

## BE-VAL-001 — @Trim on string inputs

**What to check:** Every string field on a `@InputType()` DTO has `@Trim()` applied.

**Scan:**
```
Grep pattern: "@Field\\([^)]*\\)\\s*\\n\\s*\\w+\\s*:\\s*string"
     multiline: true
     path:    ./src/**/dto
     output_mode: content
     -B:      3
```
Flag fields without a `@Trim()` decorator in the preceding decorator stack.

- **True positive:** `@Field() @IsString() name: string;` (no @Trim).
- **False positive:** Fields that truly should preserve whitespace (rare — usually a justification comment is present).
- **Confirm:** Read the class — if it's `@InputType()` and the field is string, @Trim should be present.
- **Severity:** warning

---

## BE-VAL-002 — @MinLength on required strings

**What to check:** Required (non-nullable) string inputs should have `@MinLength(1)` to reject empty-after-trim.

**Scan:**
```
Grep pattern: "@Trim\\(\\)[\\s\\S]{0,200}@IsString\\(\\)"
     multiline: true
     path:    ./src/**/dto
     output_mode: content
```
For each match, verify `@MinLength(1)` (or higher) is present and the field is not marked `@IsOptional()`.

- **True positive:** `@Trim() @IsString() name: string;` (required, no @MinLength).
- **False positive:** `@IsOptional()` marked field — empty OK.
- **Confirm:** Read the decorator stack; if non-optional and string, @MinLength expected.
- **Severity:** warning

---

## BE-VAL-003 — FK validators extend ForeignKeyExistsConstraint

**What to check:** Custom FK existence validators inherit the shared base.

**Scan:**
```
Grep pattern: "@ValidatorConstraint\\([^)]*\\)\\s*\\nexport class \\w+"
     multiline: true
     path:    ./src/**/validators
     output_mode: content
```
For each validator class, verify it extends `ForeignKeyExistsConstraint` (if the class name suggests FK validation — e.g., `PartnerExistsConstraint`, `UserExistsConstraint`).

- **True positive:** `@ValidatorConstraint() export class PartnerExistsConstraint implements ValidatorConstraintInterface` (implements from scratch instead of extending).
- **False positive:** Validators that check something other than FK existence (e.g., format validators).
- **Confirm:** Read the class body; if it's doing a `findOne({ where: { id } })` lookup, it should extend the shared constraint.
- **Severity:** warning

---

## BE-VAL-004 — Custom exceptions extend ApiException

**What to check:** Business errors thrown in services and resolvers must extend `ApiException`.

**Scan:**
```
Grep pattern: "throw new (Error|InternalServerErrorException|BadRequestException|NotFoundException|ForbiddenException)\\("
     path:    ./src
     output_mode: content
```

- **True positive:** `throw new Error('Invalid state')` or `throw new BadRequestException('bad')` in service / resolver code.
- **False positive:** Re-throwing an already-typed exception in a filter; throwing built-in exceptions inside `main.ts` bootstrap code.
- **Confirm:** Read the surrounding code; if in business logic, convert to `ApiException` subclass.
- **Severity:** warning

---

## BE-VAL-005 — No @IsUUID combined with FK validator

**What to check:** Fields decorated with a FK-existence validator (e.g., @PartnerExists) shouldn't ALSO have @IsUUID().

**Scan:**
```
Grep pattern: "@IsUUID\\([^)]*\\)"
     path:    ./src/**/dto
     output_mode: content
     -A:      3
```
For each match, check if the same field (next 1-3 lines) has a FK-existence validator.

- **True positive:** `@IsUUID() @PartnerExists() partnerId: string;`
- **False positive:** `@IsUUID()` alone on a field that's not a FK (e.g., `@IsUUID() externalReference: string`).
- **Confirm:** Check the field's decorator stack for both decorators.
- **Severity:** info
