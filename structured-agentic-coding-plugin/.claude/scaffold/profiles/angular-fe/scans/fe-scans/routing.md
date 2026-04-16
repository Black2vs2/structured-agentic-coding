# Scan Playbook: Routing & Navigation

Category: `routing` | Rules: FE-ROUTE-001 through FE-ROUTE-008

---

## FE-ROUTE-001 -- Route params via input(), never ActivatedRoute

**What to check:** Flag ActivatedRoute import, .snapshot, .paramMap usage. Route params should use `input.required<string>()` with `withComponentInputBinding()`.

**Scan:**

```
Grep pattern: "ActivatedRoute|\.snapshot|\.paramMap"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `private route = inject(ActivatedRoute)` — should use `id = input.required<string>()`
- **True positive:** `this.route.snapshot.paramMap.get('id')` — should use signal input
- **False positive:** None — ActivatedRoute should not be used for route params in this codebase
- **Confirm:** No confirmation needed. Any match is a violation.
- **Severity:** warning

---

## FE-ROUTE-002 -- Lazy loading for all page routes

**What to check:** Every page route must use `loadComponent: () => import(...)` instead of eager `component:` property.

**Scan:**

```
Grep pattern: "\bcomponent\s*:"
     path:    frontend/libs
     output_mode: content
     glob:    "*.routes.ts"
```

- **True positive:** `{ path: 'details', component: DetailsComponent }` — should use `loadComponent: () => import('./details/details.component').then(m => m.DetailsComponent)`
- **False positive:** Route configs in `app.routes.ts` for the shell/layout component — the root layout component may be eagerly loaded
- **Confirm:** Check if the route is a page route (violation) vs the root shell/layout route (acceptable).
- **Severity:** warning

---

## FE-ROUTE-003 -- Functional guards only

**What to check:** Flag class-based guards implementing CanActivate, CanDeactivate, CanLoad, or Resolve interfaces.

**Scan:**

```
Grep pattern: "implements\s+(CanActivate|CanDeactivate|CanLoad|Resolve)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `export class AuthGuard implements CanActivate` — should be a functional guard: `export const authGuard: CanActivateFn = () => { ... }`
- **False positive:** None — all guards should be functional in Angular 17+
- **Confirm:** No confirmation needed. Any match is a violation.
- **Severity:** warning

---

## FE-ROUTE-004 -- Route path conventions

**What to check:** Route paths should use kebab-case, plural nouns for lists, `:id` for entity details. Flag camelCase, snake_case, or uppercase characters in paths.

**Scan:**

```
Grep pattern: "path\s*:\s*['\"][^'\"]*[A-Z_][^'\"]*['\"]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.routes.ts"
```

- **True positive:** `path: 'userProfile'` — should be `path: 'user-profile'`
- **True positive:** `path: 'user_profile'` — should be `path: 'user-profile'`
- **False positive:** `path: ':id'` — parameter, acceptable
- **False positive:** `path: ':userId'` — parameter with camelCase is acceptable for Angular route params
- **Confirm:** Check if the uppercase/underscore is in the path string itself (violation) vs a route parameter prefixed with `:` (acceptable).
- **Severity:** info

---

## FE-ROUTE-005 -- Auth guards on all protected routes

**What to check:** Every route except `/login` and public routes must have `canActivate` with an auth guard.

**Scan 1 -- Find all route definitions:**

```
Grep pattern: "path\s*:"
     path:    frontend/libs
     output_mode: content
     glob:    "*.routes.ts"
     -C:      3
```

**Scan 2 -- Find canActivate usage:**

```
Grep pattern: "canActivate"
     path:    frontend/libs
     output_mode: content
     glob:    "*.routes.ts"
```

- **Interpretation:** Compare route definitions with canActivate presence. Routes without canActivate (excluding login/public routes) are violations.
- **True positive:** `{ path: 'candidates', loadComponent: ... }` without `canActivate: [authGuard]`
- **False positive:** `{ path: 'login', loadComponent: ... }` — login route is public, no guard needed
- **False positive:** Route with `canActivate: [authGuard]` — has guard, correct
- **Confirm:** Read the route file to identify which routes lack auth guards. Exclude login and any explicitly public routes.
- **Severity:** warning

---

## FE-ROUTE-006 -- Navigation patterns (no window.location)

**What to check:** Flag `window.location` for internal navigation. Use `Router.navigate()` or `routerLink` instead.

**Scan:**

```
Grep pattern: "window\.location\.(href|assign|replace)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `window.location.href = '/dashboard'` — should use `this.router.navigate(['/dashboard'])`
- **True positive:** `window.location.assign('/login')` — should use Router
- **False positive:** `window.location.href` used for external URL navigation (e.g., opening a third-party site) — acceptable
- **Confirm:** Read surrounding context to determine if the URL is internal (violation) vs external (acceptable).
- **Severity:** warning

---

## FE-ROUTE-007 -- Navigate to detail after entity creation

**What to check:** After a successful create API call (POST that returns an entity Id), the component must navigate to the entity's detail/edit page.

**Scan 1 -- Find create operations in stores:**

```
Grep pattern: "\.(create|add|post)\w*\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.store.ts"
     -i:      true
```

**Scan 2 -- Check for router.navigate in tap blocks:**

```
Grep pattern: "router\.navigate|Router"
     path:    frontend/libs
     output_mode: content
     glob:    "*.store.ts"
```

- **Interpretation:** For stores with create operations, verify that the `tap` block after a successful POST includes navigation to the detail page. Cross-reference create methods with router.navigate calls.
- **True positive:** Store has `createCandidate` rxMethod with `tap(() => { this.messageService.add(...) })` but no router.navigate to the new entity's detail page
- **False positive:** Store has `createCandidate` rxMethod with `tap((result) => { this.router.navigate(['/candidates', result.id, 'edit']) })` — navigates after creation
- **Confirm:** Read the store's create method tap block to verify navigation exists.
- **Priority:** Medium — requires reading store files to verify post-creation behavior.
- **Severity:** info

---

## FE-ROUTE-008 -- Routes via AppRoutes enum only

**What to check:** Flag hardcoded route path strings. All navigation must use `AppRoutes` enum from `@libs/core/routing`. For parameterized routes, use `buildRoute()`.

**Scan 1 -- Hardcoded route strings in router.navigate:**

```
Grep pattern: "router\.navigate\(\['\/"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `this.router.navigate(['/candidates', id])` — should be `this.router.navigate([buildRoute(AppRoutes.CandidateDetail, { id })])`
- **True positive:** `this.router.navigate(['/login'])` — should be `this.router.navigate([AppRoutes.Login])`
- **False positive:** None — all route strings should come from the enum
- **Confirm:** Check import of `AppRoutes` or `buildRoute` from `@libs/core/routing`. If missing, it's a violation.
- **Severity:** warning

**Scan 2 -- Hardcoded route strings in routerLink:**

```
Grep pattern: "routerLink=\"/|routerLink=\"[a-z]|\[routerLink\]=\"'/|route:\s*'/"
     path:    frontend/libs
     output_mode: content
     glob:    "*.{ts,html}"
```

- **True positive:** `routerLink="/login"` in template — should use component property bound to AppRoutes
- **True positive:** `route: '/dashboard'` in navItems — should use `AppRoutes.Dashboard`
- **False positive:** Relative routerLinks (e.g., `routerLink="register"`) within child routes — these are relative paths, not absolute route references
- **Confirm:** Check if the string is an absolute path starting with `/` (violation) vs a relative segment (acceptable).
- **Severity:** warning

**Scan 3 -- Verify AppRoutes import exists where Router is used:**

```
Grep pattern: "import.*Router.*from '@angular/router'"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.ts"
```

Cross-reference with:

```
Grep pattern: "import.*AppRoutes.*from '@libs/core/routing'"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.ts"
```

- **Interpretation:** Files that import `Router` but not `AppRoutes` likely have hardcoded route strings.
- **Severity:** info
