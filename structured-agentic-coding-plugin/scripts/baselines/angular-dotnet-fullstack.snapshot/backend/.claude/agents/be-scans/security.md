# Scan Playbook: Security & Auth

Category: `security` | Rules: BE-SEC-001 through BE-SEC-006

---

## BE-SEC-001 — No hardcoded secrets

**What to check:** Flag long alphanumeric strings that look like secrets, GitHub PATs (`ghp_*`), JWTs (`eyJ*`), `Password=` in connection strings, and secret variable literals.

**Scan 1 — GitHub PATs and JWTs:**
```
Grep pattern: "(ghp_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9+/=]{20,})"
     path:    backend/src
     output_mode: content
```
- **True positive:** `var pat = "ghp_abc123def456...";` — hardcoded PAT
- **False positive:** None — these patterns should never appear in source code
- **Confirm:** No confirmation needed.
- **Severity:** warning (critical)

**Scan 2 — Connection string passwords:**
```
Grep pattern: "Password\s*="
     path:    backend/src
     output_mode: content
     -i:      true
```
- **True positive:** `"Host=localhost;Password=mysecret123;Database=mydb"` hardcoded in source
- **False positive:** `Configuration.GetConnectionString("Default")` — reading from config, not hardcoded. Also `Password=` inside `appsettings.Development.json` example comments is borderline.
- **Confirm:** Check if the password is a literal string in source code vs a reference to configuration.
- **Severity:** warning

**Scan 3 — Secret variable assignments:**
```
Grep pattern: "(secret|apiKey|api_key|password|token)\s*=\s*\"[^\"]{8,}\""
     path:    backend/src
     output_mode: content
     -i:      true
```
- **True positive:** `var apiKey = "sk-abc123456789";` — hardcoded secret
- **False positive:** `var token = ""; // placeholder` — empty string, not a secret. Also `token = request.Token` — reading from input, not hardcoded.
- **Confirm:** Check if the value is a string literal >8 chars that looks like a real secret. Variable names like `contentType` that happen to end in `type` are not secrets.
- **Severity:** warning

---

## BE-SEC-002 — Centralized token validation

**What to check:** Public-facing endpoints must use centralized token validation logic. Flag duplicated token lookup/validation logic.

**Scan:**
```
Grep pattern: "UniqueToken|\.Token\s*==|FindByToken"
     path:    backend/src/App.Application
     output_mode: content
```
- **Interpretation:** Token validation should follow a consistent pattern. If you see different approaches to token lookup across handlers, flag the inconsistency.
- **True positive:** Different token validation logic across handlers
- **False positive:** All handlers using the same query pattern consistently
- **Confirm:** If multiple matches found, Read 2-3 of the handlers to compare their token validation code.
- **Severity:** info

---

## BE-SEC-003 — Identity through ICurrentUser only

**What to check:** Flag direct access to `HttpContext.User`, `User.FindFirst`, or `ClaimsPrincipal` outside the `ICurrentUser` implementation (`CurrentUser.cs`).

**Scan:**
```
Grep pattern: "(HttpContext\.User|User\.FindFirst|ClaimsPrincipal|ClaimsIdentity)"
     path:    backend/src
     output_mode: content
```
- **True positive:** `var email = HttpContext.User.FindFirst("email")?.Value;` in a controller action
- **False positive:** Same code inside `CurrentUser.cs` (the ICurrentUser implementation) — this IS the centralized place
- **False positive:** Same code inside authorization middleware — middleware may need direct claims access before the request reaches controllers
- **Confirm:** Check the file path of each match:
  - `Auth/CurrentUser.cs`: acceptable (this IS the abstraction)
  - Authorization middleware: acceptable (middleware runs before DI scope)
  - Any controller or handler: violation
- **Severity:** warning

---

## BE-SEC-004 — No sensitive data in prod logs

**What to check:** Flag sensitive data (emails, tokens, PII) being logged in `LogInformation`, `LogWarning`, or `LogError` calls.

**Scan:**
```
Grep pattern: "Log(Information|Warning|Error|Debug)\(.*([Ee]mail|[Tt]oken)"
     path:    backend/src
     output_mode: content
```
- **True positive:** `_logger.LogInformation("Processing for {Email}", entity.Email);` — emails in logs
- **True positive:** `_logger.LogWarning("Invalid token: {Token}", token);` — tokens in logs
- **False positive:** `_logger.LogInformation("Email service configured");` — no actual email data
- **Confirm:** Read the log statement to determine if an actual email address or token VALUE is being interpolated into the log vs just mentioning the concept.
- **Severity:** warning

---

## BE-SEC-005 — No secrets in logs at any level

**What to check:** Flag variables named `pat`, `token`, `secret`, `password`, `apiKey` appearing in log template parameters.

**Scan:**
```
Grep pattern: "Log\w*\(.*\{(pat|token|secret|password|apiKey|PAT|Token|Secret|Password|ApiKey)\}"
     path:    backend/src
     output_mode: content
```
- **True positive:** `_logger.LogDebug("Using PAT: {pat}", gitHubPat);` — secret in logs
- **False positive:** `_logger.LogInformation("Token validated for {TokenPrefix}", token[..4]);` — only logging a prefix is borderline acceptable
- **Confirm:** Check if the full secret value is being logged vs a safe representation (prefix, hash, redacted).
- **Severity:** warning

---

## BE-SEC-006 — Authorization via policies and attributes, never path-matching middleware

**What to check:** Flag any middleware that makes authorization decisions based on URL path strings. This includes `StartsWithSegments`, `path.Contains`, `path.Equals`, regex route matching, or `HashSet<string>` whitelists of paths/prefixes used to bypass or enforce authorization. Authorization must use ASP.NET authorization policies with endpoint metadata (attributes).

**Scan 1 — Path-based auth decisions in middleware:**
```
Grep pattern: "(StartsWithSegments|\.Path\.(Contains|Equals|Value)|Request\.Path\s*==)"
     path:    backend/src/App.Api
     output_mode: content
     context: 5
```
- **True positive:** `if (context.Request.Path.StartsWithSegments("/api/auth")) { await next(context); return; }` inside a middleware that checks claims or returns 401/403 — this is a path-based authorization bypass
- **True positive:** `if (path.Equals("/api/companies", StringComparison.OrdinalIgnoreCase)) { await next(context); return; }` — hardcoded path whitelist for auth bypass
- **False positive:** Path matching in non-auth middleware (e.g., logging, CORS, static files) — only flag when the match controls whether an auth check is skipped or a 401/403 is returned
- **Confirm:** Read the middleware to determine if the path match is used to skip an authorization check (claims validation, role check, 401/403 response). If the path match controls only non-auth behavior (logging, metrics), it's not a violation.
- **Severity:** warning (critical)

**Scan 2 — Whitelisted path collections:**
```
Grep pattern: "(Whitelisted|Allowed|Excluded|Bypass|Skip)(Paths|Prefixes|Routes|Endpoints)"
     path:    backend/src/App.Api
     output_mode: content
     context: 3
```
- **True positive:** `private static readonly HashSet<string> WhitelistedPrefixes = ["/api/auth", "/api/admin"];` — hardcoded path whitelist for auth bypass
- **False positive:** None — these collections in auth context are always violations
- **Confirm:** Verify the collection is used for authorization decisions (not for CORS or rate limiting).
- **Severity:** warning (critical)

**Scan 3 — Middleware returning 401/403:**
```
Grep pattern: "StatusCode\s*=\s*(401|403)"
     path:    backend/src/App.Api
     output_mode: content
     context: 10
```
- **Interpretation:** Any middleware manually setting 401/403 status codes is likely implementing authorization logic that should be in an `IAuthorizationHandler`. Read the surrounding code to determine if the decision is based on path matching.
- **True positive:** A middleware that checks claims and returns 403 with path-based whitelisting — should be an authorization policy
- **False positive:** Exception handling middleware converting `ApiException` to 401/403 — this is error mapping, not authorization
- **Confirm:** Read the full middleware. If it both matches paths AND returns 401/403, it's a violation.
- **Severity:** warning

**Proposed fix pattern:**

When a violation is found, propose refactoring to:

1. **Create a marker attribute:**
```csharp
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class BypassCompanyRequiredAttribute : Attribute;
```

2. **Create an authorization requirement + handler:**
```csharp
public class CompanyRequiredRequirement : IAuthorizationRequirement;

public class CompanyRequiredHandler : AuthorizationHandler<CompanyRequiredRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, CompanyRequiredRequirement requirement)
    {
        if (context.Resource is not HttpContext http) return Task.CompletedTask;

        var endpoint = http.GetEndpoint();
        if (endpoint?.Metadata.GetMetadata<BypassCompanyRequiredAttribute>() is not null)
        {
            context.Succeed(requirement);
            return Task.CompletedTask;
        }

        var companyId = context.User.FindFirst("companyId")?.Value;
        if (!string.IsNullOrEmpty(companyId))
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
```

3. **Register the policy and handler:**
```csharp
builder.Services.AddSingleton<IAuthorizationHandler, CompanyRequiredHandler>();
builder.Services.AddAuthorizationBuilder()
    .AddPolicy("RequiresCompany", p => p.AddRequirements(new CompanyRequiredRequirement()));
```

4. **Apply `[BypassCompanyRequired]`** on the specific actions/controllers that should skip, and apply `[Authorize(Policy = "RequiresCompany")]` on controllers that need it (or use as FallbackPolicy).

5. **Delete the path-matching middleware entirely.**
