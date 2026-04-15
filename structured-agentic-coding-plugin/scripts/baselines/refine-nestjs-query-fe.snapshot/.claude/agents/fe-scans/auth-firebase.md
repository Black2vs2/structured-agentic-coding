# Scan Playbook: Auth & Firebase

Category: `auth` | Rules: FE-AUTH-001 through FE-AUTH-004

---

## FE-AUTH-001 — Firebase token injected in data-provider

**What to check:** The dataProvider attaches the Firebase ID token to every outgoing request.

**Scan:**
```
Grep pattern: "getIdToken|idToken"
     path:    ./src/providers
     output_mode: content
```
Also:
```
Grep pattern: "Authorization.*Bearer"
     path:    ./src/providers
     output_mode: content
```

- **True positive:** No token attachment in data-provider; requests go out without Authorization header.
- **False positive:** Token attached via a shared fetch wrapper imported from another module.
- **Confirm:** Trace the data-provider's fetch implementation to confirm the token header is added.
- **Severity:** error

---

## FE-AUTH-002 — authProvider returns Firebase user

**What to check:** authProvider `check` / `getIdentity` reads from Firebase Auth.

**Scan:**
```
Grep pattern: "authProvider.*=\\s*\\{"
     multiline: true
     path:    ./src
     output_mode: content
     -A:      40
```
Inspect `check`, `login`, `logout`, `getIdentity` implementations for Firebase Auth calls.

- **True positive:** authProvider with hardcoded user object or localStorage-only state.
- **False positive:** Provider delegates to `src/lib/firebase.ts` helper functions.
- **Confirm:** Read each provider method; they must read/write Firebase Auth state.
- **Severity:** error

---

## FE-AUTH-003 — UserStateGuard wraps routed pages

**What to check:** Protected routes are wrapped with a user-state guard component.

**Scan:**
```
Grep pattern: "UserStateGuard|AuthGuard|RequireAuth"
     path:    ./src/App.tsx
     output_mode: content
     -B:      3
     -A:      5
```

- **True positive:** `<Refine>` children or routes rendered without a guard around them.
- **False positive:** Guard applied at a higher layout level (e.g., inside `<Outlet>` of a parent route).
- **Confirm:** Trace the component tree from `<Routes>` down; every protected page must sit under the guard.
- **Severity:** warning

---

## FE-AUTH-004 — No direct Firebase Auth calls in pages

**What to check:** Firebase Auth APIs (signIn, signOut, onAuthStateChanged) are centralized — not called from resource pages.

**Scan:**
```
Grep pattern: "signInWithEmailAndPassword|signOut\\s*\\(|onAuthStateChanged"
     path:    ./src/resources
     output_mode: content
```
Also check `./src/pages`.

- **True positive:** Direct `signIn*` call in a resource page or non-provider page.
- **False positive:** Those calls are allowed in `src/lib/firebase.ts` and `src/providers/auth-provider.ts`.
- **Confirm:** Check file path; pages/resources outside providers/lib should not call Firebase Auth directly.
- **Severity:** warning
