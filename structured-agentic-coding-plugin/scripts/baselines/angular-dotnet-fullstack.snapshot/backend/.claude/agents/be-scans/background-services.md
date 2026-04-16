# Scan Playbook: Background Services

Category: `background-services` | Rules: BE-BG-001 through BE-BG-003

---

## BE-BG-001 — Error handling in loops

**What to check:** `ExecuteAsync` in background services must have per-iteration `try/catch` inside the main loop. An unhandled exception should never exit the loop (which would kill the service).

**Scan:**
```
Grep pattern: "while\s*\(!?stoppingToken"
     path:    backend/src/App.Api/BackgroundServices
     output_mode: content
     context: 10
```
- **Interpretation:** Inside the `while (!stoppingToken.IsCancellationRequested)` loop, there should be a `try/catch` wrapping the iteration body. If the loop body has no try/catch, one exception stops the service.
- **True positive:** A while loop without a `try { ... } catch { ... }` inside it
- **False positive:** A while loop with `try/catch` inside — correct pattern
- **Confirm:** The context=10 should show the loop body. If the try/catch isn't visible, Read the full method to verify.

Also check `foreach`-based processing inside services:
```
Grep pattern: "foreach\s*\("
     path:    backend/src/App.Api/BackgroundServices
     output_mode: content
     context: 5
```
- **True positive:** `foreach (var item in items) { await Process(item); }` without try/catch — one bad item kills all
- **False positive:** `foreach` inside a try/catch block — correct
- **Severity:** warning

---

## BE-BG-002 — Config-driven intervals

**What to check:** Background service timing intervals must come from `IOptions<T>` or `IConfiguration`, not hardcoded literals.

**Scan:**
```
Grep pattern: "TimeSpan\.(FromSeconds|FromMinutes|FromHours|FromMilliseconds)\(\d+"
     path:    backend/src/App.Api/BackgroundServices
     output_mode: content
```
- **True positive:** `await Task.Delay(TimeSpan.FromMinutes(10), stoppingToken);` — hardcoded 10 minutes
- **True positive:** `var interval = TimeSpan.FromSeconds(60);` — hardcoded 60 seconds
- **False positive:** `TimeSpan.FromSeconds(config.PollingIntervalSeconds)` — reading from config (but this wouldn't match the digit pattern anyway)
- **Confirm:** Check if the argument to `TimeSpan.From*` is a literal number or a configuration value. Also check:
  ```
  Grep pattern: "IOptions|IConfiguration|\.GetValue"
       path:    backend/src/App.Api/BackgroundServices
  ```
  If the service doesn't inject any configuration, it's likely using hardcoded values.
- **Severity:** info

Also check for `new TimeSpan(...)`:
```
Grep pattern: "new TimeSpan\(\d"
     path:    backend/src/App.Api/BackgroundServices
     output_mode: content
```

---

## BE-BG-003 — Graceful shutdown

**What to check:** `stoppingToken` must be passed to all async operations inside the background service loop: `Task.Delay`, HTTP calls, DB queries, and the loop condition itself.

**Scan 1 — Task.Delay without cancellation token:**
```
Grep pattern: "Task\.Delay\([^)]*\)"
     path:    backend/src/App.Api/BackgroundServices
     output_mode: content
```
- **True positive:** `await Task.Delay(TimeSpan.FromMinutes(5));` — no `stoppingToken` parameter
- **False positive:** `await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);` — correct
- **Confirm:** Check if `stoppingToken` (or `cancellationToken`) appears as the second argument to `Task.Delay`.
- **Severity:** warning

**Scan 2 — Async operations without token:**
```
Grep pattern: "(SaveChangesAsync|ToListAsync|FirstOrDefaultAsync|SendAsync)\(\s*\)"
     path:    backend/src/App.Api/BackgroundServices
     output_mode: content
```
- **True positive:** `await db.SaveChangesAsync();` — should pass `stoppingToken`
- **False positive:** `await db.SaveChangesAsync(stoppingToken);` — correct (but wouldn't match this pattern since parentheses aren't empty)
- **Severity:** info

**Scan 3 — Loop condition uses stoppingToken:**
Already covered by BE-BG-001 scan. The `while (!stoppingToken.IsCancellationRequested)` check verifies this.
