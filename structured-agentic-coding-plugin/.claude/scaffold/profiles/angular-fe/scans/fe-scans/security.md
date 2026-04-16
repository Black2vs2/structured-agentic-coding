# Scan Playbook: Security & Auth

Category: `auth` | Rules: FE-AUTH-001 through FE-AUTH-003

---

## FE-AUTH-001 -- Token access only through auth service

**What to check:** Flag localStorage/sessionStorage access outside the auth service. Flag direct Authorization header construction outside the interceptor.

**Scan 1 -- localStorage/sessionStorage access:**

```
Grep pattern: "localStorage\.(getItem|setItem|removeItem)|sessionStorage\.(getItem|setItem|removeItem)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `localStorage.getItem('token')` in a component or service other than auth
- **False positive:** Same code in `auth.service.ts` or `auth.interceptor.ts` — these are the centralized locations
- **Confirm:** Check file path — auth service and interceptor are the only acceptable locations
- **Severity:** warning

**Scan 2 -- Direct Authorization header construction:**

```
Grep pattern: "Authorization.*Bearer|Bearer.*token|headers\.(set|append)\(.*Authorization"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `headers.set('Authorization', 'Bearer ' + token)` in a service or component
- **False positive:** Same code in `auth.interceptor.ts` — the interceptor is the centralized place for auth headers
- **Confirm:** Check file path — only the auth interceptor should set Authorization headers
- **Severity:** warning

---

## FE-AUTH-002 -- No secrets in code

**What to check:** Scan for hardcoded API keys, JWTs, long base64 strings, and secret variable assignments.

**Scan 1 -- GitHub PATs and JWTs:**

```
Grep pattern: "(ghp_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9+/=]{20,})"
     path:    frontend/
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `const token = "eyJhbGciOiJIUzI1NiIs..."` — hardcoded JWT
- **False positive:** None — these patterns should never appear in source code
- **Confirm:** No confirmation needed.
- **Severity:** warning (critical)

**Scan 2 -- Secret variable assignments:**

```
Grep pattern: "(apiKey|api_key|secret|password)\s*[:=]\s*['\"][^'\"]{8,}"
     path:    frontend/
     output_mode: content
     glob:    "*.ts"
     -i:      true
```

- **True positive:** `const apiKey = "sk-abc123456789";` — hardcoded secret
- **False positive:** `apiKey: environment.apiKey` — reading from config, not hardcoded
- **False positive:** `password: string` — type declaration, not an assignment
- **Confirm:** Check if the value is a string literal >8 chars that looks like a real secret vs reading from config.
- **Severity:** warning

---

## FE-AUTH-003 -- Vulnerability scanning

**What to check:** Flag innerHTML usage, bypassSecurityTrust\* calls, eval(), and new Function().

**Scan 1 -- innerHTML and bypass:**

```
Grep pattern: "\[innerHTML\]|bypassSecurityTrust"
     path:    frontend/libs
     output_mode: content
     glob:    "*.{ts,html}"
```

- **True positive:** `[innerHTML]="userContent"` without DomSanitizer verification
- **False positive:** `[innerHTML]="sanitizedHtml"` where a DomSanitizer pipe or method is clearly used in the chain
- **Confirm:** Read the component to check if DomSanitizer is applied before rendering. `bypassSecurityTrust*` itself is a red flag even with sanitizer — it bypasses Angular's built-in protection.
- **Severity:** warning

**Scan 2 -- Dynamic code execution:**

```
Grep pattern: "\beval\(|new Function\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `eval(userInput)` — dynamic code execution
- **True positive:** `new Function('return ' + expr)` — dynamic function creation
- **False positive:** None — these should never appear in application code
- **Confirm:** No confirmation needed.
- **Severity:** warning (critical)
