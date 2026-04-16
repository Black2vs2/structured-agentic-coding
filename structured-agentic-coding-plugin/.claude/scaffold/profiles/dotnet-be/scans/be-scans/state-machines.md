# Scan Playbook: State Machines

Category: `state-machines` | Rules: BE-STATE-001 through BE-STATE-005

---

## BE-STATE-001 — Transitions via entity methods

**What to check:** Status changes on entities must go through dedicated entity methods (e.g., `entity.Activate()`, `entity.Complete()`). Flag direct status assignment like `entity.Status = EntityStatus.Active` in handlers.

**Scan:**
```
Grep pattern: "\.(Status|InviteStatus|EvaluationStatus)\s*=\s*(\w+Status)\."
     path:    backend/src/__BE_NAMESPACE__.Application
     output_mode: content
```
- **True positive:** `entity.Status = EntityStatus.Active;` in a handler — should use `entity.Activate()`
- **False positive:** Status set during initial entity creation in `new Entity { Status = EntityStatus.Draft }` — acceptable for initial state only
- **Confirm:** Read surrounding context to determine if this is:
  1. Initial creation (object initializer with `new`): acceptable
  2. Mutation of existing entity loaded from DB: violation — must use entity method
- **Severity:** warning

Note: This overlaps with BE-ENTITY-002. Report under BE-STATE-001 to avoid duplicates.

---

## BE-STATE-002 — Transitions audit-logged

**What to check:** Entity transition methods must capture the old state before changing it. This enables audit logging.

**Scan:**
```
Grep pattern: "void (MarkAs|Start|Complete|Revoke|Expire|Fail|Cancel)\w*\("
     path:    backend/src/__BE_NAMESPACE__.Domain/Entities
     output_mode: content
     context: 5
```
- **Interpretation:** For each transition method found, check if it captures the old state (e.g., `var oldStatus = Status;`) before assigning the new state.
- **True positive:** A transition method that directly sets `Status = EntityStatus.Completed;` without storing old state
- **False positive:** A method that stores old state: `var prev = Status; Status = EntityStatus.Completed;`
- **Confirm:** The context=5 from Grep should show enough of the method body. If not visible, Read the file with offset/limit to see the full method.
- **Severity:** info

---

## BE-STATE-003 — Terminal states immutable

**What to check:** Code must check for terminal state before allowing mutations. Terminal states are entity-specific (e.g., `Completed`, `Expired`, `Revoked`, `Failed`).

**Scan 1 — Check transition methods for terminal guards:**
```
Grep pattern: "IsTerminal|is.*Terminal"
     path:    backend/src/__BE_NAMESPACE__.Domain/Entities
     output_mode: content
     context: 3
```

**Scan 2 — Check handlers for terminal state checks before mutation:**
```
Grep pattern: "IsTerminal"
     path:    backend/src/__BE_NAMESPACE__.Application
     output_mode: content
```
- **Interpretation:** Handlers that mutate entity status should check `IsTerminal` before proceeding. If a handler calls a transition method without first checking terminal state, AND the entity's transition method itself doesn't check, that's a gap.

**Scan 3 — Check entity transition methods guard against terminal:**
Read entity files containing transition methods and verify each either:
1. Checks `if (IsTerminal) throw new ConflictException(...)` at the top, OR
2. Checks the specific disallowed source states
- **True positive:** A transition method that doesn't guard against being called on a terminal entity
- **Severity:** warning

---

## BE-STATE-004 — Evaluation state machine rigor

**What to check:** Entities with status enums must have explicit transition methods with validation and terminal checks.

**Scan:**
```
Grep pattern: "public void (MarkInProgress|Complete|Fail|MarkAs|Activate|Deactivate)"
     path:    backend/src/__BE_NAMESPACE__.Domain/Entities
     output_mode: content
```
- **Interpretation:** If no transition methods are found on entities with status enums, that's a violation — status is being set directly by handlers.
- **True positive:** Entity with status enum but no transition methods (status set directly in handlers)
- **False positive:** Entity with proper transition methods that validate transitions
- **Confirm:** If no methods found, also check handlers for direct status assignment.
- **Severity:** warning

---

## BE-STATE-005 — State machines documented

**What to check:** Entities with status enum properties must document valid transitions in a code comment.

**Scan:**
```
Grep pattern: "(\w+Status)\s+Status"
     path:    backend/src/__BE_NAMESPACE__.Domain/Entities
     output_mode: content
     -B:      5
```
- **Interpretation:** Check the 5 lines before the Status property for a comment block describing valid transitions (e.g., `// Draft -> Active -> Completed -> ...`).
- **True positive:** `public MyStatus Status { get; set; }` with no transition documentation in surrounding comments
- **False positive:** Same property with a comment block above it describing the state machine
- **Confirm:** The -B=5 context should show preceding lines. If no state machine documentation visible, Read more of the file (class-level XML doc comment or top of file).
- **Severity:** info
