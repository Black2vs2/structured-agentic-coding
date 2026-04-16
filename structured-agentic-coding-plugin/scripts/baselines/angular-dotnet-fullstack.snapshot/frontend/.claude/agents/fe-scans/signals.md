# Scan Playbook: Signals & Reactivity

Category: `signals` | Rules: FE-SIG-001 through FE-SIG-005

---

## FE-SIG-001 -- Signal-based component API only

**What to check:** Flag legacy decorator-based component API: `@Input()`, `@Output()`, `@ViewChild()`, `@ViewChildren()`, `@ContentChild()`, `@ContentChildren()`.

**Scan:**

```
Grep pattern: "@Input\(|@Output\(|@ViewChild\(|@ViewChildren\(|@ContentChild\(|@ContentChildren\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `@Input() name: string` — should use `name = input.required<string>()`
- **True positive:** `@Output() clicked = new EventEmitter<void>()` — should use `clicked = output<void>()`
- **True positive:** `@ViewChild('ref') el: ElementRef` — should use `el = viewChild<ElementRef>('ref')`
- **False positive:** None — all decorator-based API should be migrated to signals
- **Confirm:** No confirmation needed. Any match is a violation.
- **Severity:** warning

---

## FE-SIG-002 -- Signals over RxJS in components

**What to check:** In components (not stores/services), flag BehaviorSubject, Subject, combineLatest, merge when signal/computed would suffice.

**Scan:**

```
Grep pattern: "BehaviorSubject|Subject<|combineLatest|merge\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.component.ts"
```

- **True positive:** `private items$ = new BehaviorSubject<Item[]>([])` in a component — should use `signal<Item[]>([])`
- **True positive:** `combineLatest([this.a$, this.b$])` in a component — should use `computed(() => ...)`
- **False positive:** Same patterns in `*.store.ts` or `*.service.ts` — RxJS is appropriate there
- **Confirm:** Read the component to verify if signal/computed would suffice. Some complex stream operations may legitimately require RxJS even in components.
- **Severity:** info

---

## FE-SIG-003 -- No async pipe in templates

**What to check:** Flag every `| async` usage in HTML templates. Use `toSignal()` in the component and signal calls in the template instead.

**Scan:**

```
Grep pattern: "\| async"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `{{ items$ | async }}` — should use `items()` signal in template with `toSignal()` in component
- **True positive:** `*ngIf="data$ | async as data"` — should use `@if (data()) {`
- **False positive:** None — async pipe should not be used in this codebase
- **Confirm:** No confirmation needed. Any match is a violation.
- **Severity:** warning

---

## FE-SIG-004 -- Subscription cleanup with takeUntilDestroyed

**What to check:** In components, every `.subscribe()` must have `takeUntilDestroyed()` before it in the pipe chain.

**Scan 1 -- Find subscribe calls in components:**

```
Grep pattern: "\.subscribe\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.component.ts"
```

**Scan 2 -- Find takeUntilDestroyed in same files:**

```
Grep pattern: "takeUntilDestroyed"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.component.ts"
```

- **Interpretation:** Compare the two results. Files with `.subscribe()` but without `takeUntilDestroyed` are likely violations. Files with both still need verification that each subscribe has its own takeUntilDestroyed.
- **True positive:** `this.route.params.subscribe(p => ...)` without takeUntilDestroyed in the pipe chain
- **False positive:** `this.route.params.pipe(takeUntilDestroyed()).subscribe(p => ...)` — has cleanup
- **Confirm:** Read component files with `.subscribe()` to verify each subscription has `takeUntilDestroyed()` in its pipe chain.
- **Severity:** warning

Note: Overlaps with FE-STATE-006. Report under FE-SIG-004 for the specific takeUntilDestroyed requirement.

---

## FE-SIG-005 -- No complex logic in templates

**What to check:** Flag method calls in template interpolations and property bindings. Event handlers are acceptable.

**Scan 1 -- Method calls in interpolations:**

```
Grep pattern: "\{\{[^}]*\w+\([^)]*\)[^}]*\}\}"
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

**Scan 2 -- Method calls in property bindings:**

```
Grep pattern: "\[\w+\]\s*=\s*['\"]?\w+\("
     path:    frontend/libs
     output_mode: content
     glob:    "*.html"
```

- **True positive:** `{{ getFullName() }}` — method call in interpolation, runs every change detection cycle
- **True positive:** `[class]="getClass(item)"` — method call in property binding
- **False positive:** `(click)="onEdit(item)"` — event handler, acceptable
- **False positive:** `{{ 'key' | translate }}` — pipe, not a method call
- **False positive:** `{{ store.items() }}` — signal call, acceptable (signals are efficient)
- **Confirm:** Check if the match is an interpolation/binding (violation) vs event handler `(event)=` (acceptable) vs signal call `signalName()` (acceptable). Signal calls are fine because they are change-detection-aware.
- **Severity:** warning

Note: Overlaps with FE-PERF-001. Report under FE-SIG-005 to avoid duplicates.
