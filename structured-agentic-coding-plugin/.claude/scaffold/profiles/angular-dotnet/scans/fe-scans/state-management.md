# Scan Playbook: State Management

Category: `state-management` | Rules: FE-STATE-001 through FE-STATE-011

---

## FE-STATE-001 -- signalStore for shared state and API calls

**What to check:** Flag direct API service injection in components (not stores/services). API calls must go through stores.

**Scan 1 -- Generated API service injection in components:**

```
Grep pattern: "inject\(\w+Service\)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.component.ts"
```

- **True positive:** `private api = inject(CandidatesService)` in a `.component.ts` file — should use the store
- **False positive:** `inject(MessageService)` or `inject(TranslateService)` — UI services are acceptable in components
- **False positive:** `inject(ConfirmationService)` or `inject(DialogService)` — PrimeNG UI services are acceptable
- **Confirm:** Check if the injected service is a generated API service (from `@libs/core/api`) vs a UI/utility service. Only API services must go through stores.
- **Severity:** warning

---

## FE-STATE-002 -- withPaginatedList for paginated APIs

**What to check:** Scan for manual pagination state in stores. Stores with paginated endpoints must use `withPaginatedList`.

**Scan:**

```
Grep pattern: "(page|pageSize|pageIndex|offset)\s*[:=]"
     path:    frontend/libs
     output_mode: content
     glob:    "*.store.ts"
```

- **True positive:** `page: 0, pageSize: 10` as manual state properties instead of using `withPaginatedList`
- **False positive:** `pageSize` used within a `withPaginatedList` custom feature — that's the correct abstraction
- **Confirm:** Read the store file to check if it uses `withPaginatedList` or manages pagination manually.
- **Severity:** info

---

## FE-STATE-003 -- Store composition order

**What to check:** Verify store composition follows `withState` -> `withComputed` -> `withMethods` -> custom features.

**Scan 1 -- Find all store definitions:**

```
Grep pattern: "signalStore\("
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.store.ts"
```

**Scan 2 -- Check for withMethods before withComputed:**

```
Grep pattern: "withMethods"
     path:    frontend/libs
     output_mode: content
     glob:    "*.store.ts"
```

- **Interpretation:** For each store file, Read it to verify the order: `withState(...)` appears first, then `withComputed(...)`, then `withMethods(...)`. Any reordering is a violation.
- **True positive:** `signalStore(withState(...), withMethods(...), withComputed(...))` — withMethods before withComputed
- **False positive:** `signalStore(withState(...), withComputed(...), withMethods(...))` — correct order
- **Confirm:** Read each store file found to verify ordering. The Grep result alone cannot confirm violations — requires structural reading.
- **Severity:** info

---

## FE-STATE-004 -- rxMethod pattern: tap(loading) -> switchMap -> tap(success) -> catchError -> finalize

**What to check:** Every rxMethod with a loading flag must follow this pipe order: (1) `tap(() => patchState(store, { saving: true }))` BEFORE switchMap to set loading, (2) switchMap expression-only with inner pipe containing `tap` (success), `catchError(() => EMPTY)` (error handling), and `finalize` (cleanup loading). Flag any rxMethod missing catchError or finalize, and flag patchState for loading inside switchMap.

**Scan 1 -- Find all rxMethod usages:**

```
Grep pattern: "rxMethod"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.store.ts"
```

**Scan 2 -- Cross-reference with catchError:**

```
Grep pattern: "catchError"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.store.ts"
```

**Scan 3 -- Cross-reference with finalize:**

```
Grep pattern: "finalize"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.store.ts"
```

- **Interpretation:** Compare the three file lists. Files with `rxMethod` but missing `catchError` or `finalize` are violations.
- **True positive:** Store file with `rxMethod(pipe(switchMap(...), tap(...)))` — missing catchError and finalize
- **False positive:** Store file with `rxMethod(pipe(switchMap(...), tap(...), catchError(() => EMPTY), finalize(...)))` — complete chain
- **Confirm:** Read store files where catchError or finalize is missing to verify each rxMethod has the complete operator chain. A file may have multiple rxMethods where some are correct and others are not.
- **Severity:** warning

---

## FE-STATE-005 -- No direct HttpClient injection

**What to check:** Flag `HttpClient` import or injection anywhere in the codebase. All HTTP calls must go through generated API services.

**Scan:**

```
Grep pattern: "HttpClient"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `inject(HttpClient)` or `constructor(private http: HttpClient)` in any file
- **False positive:** None — HttpClient should never be directly used. Generated services handle all HTTP.
- **Confirm:** No confirmation needed. Any match is a violation.
- **Severity:** warning

---

## FE-STATE-006 -- No .subscribe() in components

**What to check:** Flag `.subscribe()` calls in component files. API/store calls should use store rxMethod. UI-only subscriptions need takeUntilDestroyed().

**Scan:**

```
Grep pattern: "\.subscribe\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.component.ts"
```

- **True positive:** `.subscribe(data => this.items = data)` in a component without takeUntilDestroyed
- **False positive:** `.pipe(takeUntilDestroyed()).subscribe(...)` — has cleanup, acceptable for UI-only
- **Confirm:** Read the surrounding code to check for `takeUntilDestroyed()` in the pipe chain before `.subscribe()`.
- **Severity:** warning

Note: Overlaps with FE-SIG-004. Report under FE-STATE-006 for component-level subscribe violations; report under FE-SIG-004 for missing takeUntilDestroyed specifically.

---

## FE-STATE-007 -- No unsafe type casts on API calls

**What to check:** Flag `as any`, `as Observable<any>`, `as unknown` on generated API service calls.

**Scan:**

```
Grep pattern: "as any|as Observable<any>|as unknown"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `this.api.getCandidates() as any` — unsafe cast on API call
- **False positive:** Same in `*.spec.ts` or `generated/` files — excluded from scope
- **Confirm:** Check file path to exclude test files and generated code. Check if the cast is on an API service call specifically.
- **Severity:** warning

---

## FE-STATE-008 -- No async/await in signalStore methods

**What to check:** Inside `withMethods` of signalStore, flag async functions, `firstValueFrom()`, `lastValueFrom()`, or Promise-based calls. All API calls in stores must use `rxMethod` with a pipe-based reactive stream.

**Scan 1 -- async in store files:**

```
Grep pattern: "async "
     path:    frontend/libs
     output_mode: content
     glob:    "*.store.ts"
```

**Scan 2 -- firstValueFrom/lastValueFrom:**

```
Grep pattern: "firstValueFrom|lastValueFrom"
     path:    frontend/libs
     output_mode: content
     glob:    "*.store.ts"
```

- **True positive:** `async loadItems() { const data = await firstValueFrom(this.api.getItems()); }` in a store withMethods block
- **False positive:** `async` keyword in a test file or utility service (not a store)
- **Confirm:** Read the store file to verify the `async` is inside a `withMethods` block. `async` in standalone utility functions outside the store is acceptable.
- **Severity:** warning

### DON'T — async/await with firstValueFrom

**Simple API call returning data:**

```typescript
// ❌ Breaks reactive stream, no error recovery, no cancellation
async exportChallenge(challengeId: string): Promise<ChallengeExportDto> {
  return await firstValueFrom(challengesService.exportChallenge({ id: challengeId }));
}
```

**API call with try/catch state management:**

```typescript
// ❌ Manual try/catch duplicates what catchError/finalize do natively
async togglePublished(): Promise<void> {
  const challenge = store.challenge();
  if (!challenge) return;
  patchState(store, { saving: true });
  try {
    const updated = await firstValueFrom(
      challengesService.updateChallenge({ id: challenge.id, body: { ...challenge, isPublished: !challenge.isPublished } }),
    );
    patchState(store, { challenge: { ...challenge, ...updated }, saving: false });
  } catch {
    patchState(store, { saving: false });
  }
}
```

**Sequential await chains:**

```typescript
// ❌ Each await is a separate promise — no stream composition, no cancellation
async importQuiz(challengeId: string, data: ExportQuizDto): Promise<void> {
  patchState(store, { saving: true });
  try {
    await firstValueFrom(challengesService.importQuiz({ id: challengeId, body: { data } }));
    const questions = await firstValueFrom(challengesService.getQuestionsByChallenge({ id: challengeId }));
    const challenge = await firstValueFrom(challengesService.getChallengeById({ id: challengeId }));
    patchState(store, { questions, challenge, saving: false });
  } catch {
    patchState(store, { saving: false });
  }
}
```

### DO — rxMethod with flat pipe composition

**Key principle:** switchMap is expression-only (no block body). State changes (`patchState`), guards (`filter`), and store reads (`map`) go in separate pipe steps before `switchMap`.

**Simple API call → store result in state:**

```typescript
// ✅ Reactive, cancellable, error-safe
exportChallenge: rxMethod<string>(
  pipe(
    switchMap((challengeId) =>
      challengesService.exportChallenge({ id: challengeId }).pipe(
        tap((data) => patchState(store, { challengeExport: data })),
        catchError(() => EMPTY),
      ),
    ),
  ),
),
```

**API call needing store state → map + filter + tap before switchMap:**

```typescript
// ✅ Each pipe step does one thing. switchMap only does the API call.
togglePublished: rxMethod<void>(
  pipe(
    map(() => store.challenge()),
    filter(Boolean),
    tap(() => patchState(store, { saving: true })),
    switchMap((challenge) =>
      challengesService.updateChallenge({
        id: challenge.id,
        body: { ...challenge, isPublished: !challenge.isPublished },
      }).pipe(
        tap((updated) => patchState(store, { challenge: { ...challenge, ...updated } })),
        catchError(() => EMPTY),
        finalize(() => patchState(store, { saving: false })),
      ),
    ),
  ),
),
```

**Sequential calls → tap for loading, switchMap expression with forkJoin:**

```typescript
// ✅ Single stream — cancellable, composable, error-safe
importQuiz: rxMethod<{ challengeId: string; data: ExportQuizDto }>(
  pipe(
    tap(() => patchState(store, { saving: true })),
    switchMap(({ challengeId, data }) =>
      challengesService.importQuiz({ id: challengeId, body: { data } }).pipe(
        switchMap(() =>
          forkJoin({
            questions: challengesService.getQuestionsByChallenge({ id: challengeId }),
            challenge: challengesService.getChallengeById({ id: challengeId }),
          }),
        ),
        tap(({ questions, challenge }) =>
          patchState(store, { questions: Array.isArray(questions) ? questions : [], challenge }),
        ),
        catchError(() => EMPTY),
        finalize(() => patchState(store, { saving: false })),
      ),
    ),
  ),
),
```

---

## FE-STATE-009 -- Concise catchError syntax

**What to check:** Flag catchError with block body that only returns EMPTY. Must use expression form.

**Scan:**

```
Grep pattern: "catchError\(\(\)\s*=>\s*\{"
     path:    frontend/libs
     output_mode: content
     glob:    "*.store.ts"
```

- **True positive:** `catchError(() => { return EMPTY; })` — unnecessary block body
- **False positive:** `catchError((err) => { console.error(err); return EMPTY; })` — block body with additional logic is acceptable (though console.error would be flagged by FE-HYGIENE-001)
- **Confirm:** Read the catchError block to check if it contains only `return EMPTY;` (violation) or has additional logic (acceptable block body).
- **Severity:** info

---

## FE-STATE-010 -- rxMethod calls require injection context

**What to check:** Flag rxMethod calls with signal/observable arguments outside an injection context (constructor, field initializer). Common violation: calling `store.loadSomething(signal)` inside ngOnInit or afterNextRender without passing an injector.

**Scan 1 -- rxMethod calls in lifecycle hooks:**

```
Grep pattern: "ngOnInit|afterNextRender|ngAfterViewInit"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.component.ts"
```

**Scan 2 -- Check for injector param in those files:**

```
Grep pattern: "injector"
     path:    frontend/libs
     output_mode: content
     glob:    "*.component.ts"
```

- **Interpretation:** Components that call store rxMethod inside lifecycle hooks (ngOnInit, afterNextRender) need to either: (a) pass `{ injector: this.injector }` as second argument, or (b) move the call to a field initializer/constructor.
- **True positive:** `ngOnInit() { this.store.loadItems(this.filter); }` — rxMethod called in lifecycle without injector
- **False positive:** `ngOnInit() { this.store.loadItems(this.filter, { injector: this.injector }); }` — has injector
- **False positive:** `filter = input.required<string>(); loadEffect = effect(() => { this.store.loadItems(this.filter()); });` — using effect which has injection context
- **Confirm:** Read the component file to verify whether the rxMethod call is in a lifecycle hook and whether an injector is provided.
- **Severity:** warning

---

## FE-STATE-011 -- rxMethod pipe composition: no switchMap block bodies, loading state always in tap before switchMap

**What to check:** In rxMethod pipes, flag TWO patterns:

1. `switchMap`/`exhaustMap` with block body (`=> { ... return ...; }`). switchMap must be expression-only (`=> service.call().pipe(...)`).
2. `patchState(store, { saving: true })` or `patchState(store, { loading: true })` INSIDE `switchMap` callback. Loading state must always be set in a `tap()` operator BEFORE switchMap.

Side effects (patchState for loading), guards (filter), and store reads (map(() => store.x())) go in separate pipe operators before switchMap.

**Scan 1 — switchMap block bodies:**

```
Grep pattern: "switchMap\([^)]*\)\s*=>\s*\{"
     path:    frontend/libs
     output_mode: content
     glob:    "*.store.ts"
```

**Scan 2 — patchState for loading inside switchMap (multiline):**

```
Grep pattern: "switchMap\(.*\n.*patchState\(store,\s*\{\s*(saving|loading)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.store.ts"
     multiline: true
```

- **True positive:** `switchMap((id) => { patchState(store, { loading: true }); return service.get({ id }).pipe(...); })` — block body with mixed concerns
- **True positive:** `switchMap(({ challengeId, stories }) => { patchState(store, { saving: true }); return service.batchUpdate(...)` — loading patchState inside switchMap
- **True positive:** `switchMap(() => { const item = store.item(); if (!item) return EMPTY; return service.update(item).pipe(...); })` — guard + store read inside switchMap
- **False positive:** Block body inside inner pipe (e.g., `tap(() => { ... })`) — only switchMap/exhaustMap at the top level of the rxMethod pipe is checked
- **Confirm:** Read the rxMethod to verify the block body. Check whether it can be refactored to `map` + `filter` + `tap` steps before an expression-only `switchMap`.
- **Severity:** warning

### DON'T — switchMap with block body

```typescript
// ❌ Block body mixes guard, state change, and API call in one operator
saveItem: rxMethod<void>(
  pipe(
    switchMap(() => {
      const item = store.item();
      if (!item) return EMPTY;
      patchState(store, { saving: true });
      return service.update({ id: item.id, body: item }).pipe(
        tap((res) => patchState(store, { item: res })),
        catchError(() => EMPTY),
        finalize(() => patchState(store, { saving: false })),
      );
    }),
  ),
),
```

### DON'T — patchState for loading inside switchMap callback

```typescript
// ❌ patchState({ saving: true }) is inside switchMap — must be in tap() BEFORE switchMap
batchUpdate: rxMethod<{ challengeId: string; stories: UserStoryDto[] }>(
  pipe(
    switchMap(({ challengeId, stories }) => {
      patchState(store, { saving: true });
      return service.batchUpdateUserStories({ id: challengeId, body: { stories } }).pipe(
        tap((updated) => patchState(store, { userStories: updated })),
        catchError(() => EMPTY),
        finalize(() => patchState(store, { saving: false })),
      );
    }),
  ),
),
```

### DO — flat pipe with separate operators

```typescript
// ✅ Each step does one thing — scannable, composable
saveItem: rxMethod<void>(
  pipe(
    map(() => store.item()),
    filter(Boolean),
    tap(() => patchState(store, { saving: true })),
    switchMap((item) =>
      service.update({ id: item.id, body: item }).pipe(
        tap((res) => patchState(store, { item: res })),
        catchError(() => EMPTY),
        finalize(() => patchState(store, { saving: false })),
      ),
    ),
  ),
),
```

### DO — loading state in tap BEFORE switchMap, switchMap expression-only

```typescript
// ✅ tap() sets loading, switchMap is expression-only with API call
batchUpdate: rxMethod<{ challengeId: string; stories: UserStoryDto[] }>(
  pipe(
    tap(() => patchState(store, { saving: true })),
    switchMap(({ challengeId, stories }) =>
      service.batchUpdateUserStories({ id: challengeId, body: { stories } }).pipe(
        tap((updated) => patchState(store, { userStories: updated })),
        catchError(() => EMPTY),
        finalize(() => patchState(store, { saving: false })),
      ),
    ),
  ),
),
```
