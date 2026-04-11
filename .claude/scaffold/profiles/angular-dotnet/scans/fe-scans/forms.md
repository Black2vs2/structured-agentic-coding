# Scan Playbook: Forms

Category: `forms` | Rules: FE-FORM-001 through FE-FORM-004

---

## FE-FORM-001 -- All forms extend BaseFormComponent<T>

**What to check:** Components with `form()` or `FormField` must extend `BaseFormComponent<T>`.

**Scan 1 -- Find form components:**

```
Grep pattern: "FormField|new FormField|form\("
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.component.ts"
```

**Scan 2 -- Check for BaseFormComponent extension:**

```
Grep pattern: "BaseFormComponent"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.component.ts"
```

- **Interpretation:** Compare the two file lists. Files with FormField/form() but without BaseFormComponent are violations.
- **True positive:** `export class CandidateFormComponent { form = form({...}) }` — should `extends BaseFormComponent<CandidateForm>`
- **False positive:** `export class CandidateFormComponent extends BaseFormComponent<CandidateForm>` — correct
- **Confirm:** Read the component class declaration to verify the `extends` clause.
- **Severity:** warning

---

## FE-FORM-002 -- Forms emit save, never handle submission

**What to check:** Form components must have an `output()` named `save`. They must NOT inject stores or API services.

**Scan 1 -- Store/API injection in form components:**

```
Grep pattern: "inject\(.*Store\)|inject\(.*Service\)"
     path:    frontend/libs
     output_mode: content
     glob:    "*.component.ts"
```

- **Interpretation:** Cross-reference with form component files (from FE-FORM-001 scan). Only flag inject calls in files that also contain FormField/form().
- **True positive:** `inject(CandidatesStore)` in a form component — forms should not inject stores
- **False positive:** `inject(MessageService)` or `inject(TranslateService)` in a form component — UI services are acceptable
- **Confirm:** Check if the injected service is a store or API service (violation) vs a UI service (acceptable). Also verify the component is a form component (has FormField/form()).
- **Severity:** warning

**Scan 2 -- Check for save output:**

```
Grep pattern: "save\s*=\s*output|output.*save"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.component.ts"
```

- **Interpretation:** Cross-reference with form component files. Form components without a `save` output are violations.
- **True positive:** Form component without `save = output<FormData>()` declaration
- **False positive:** Non-form component without save output — save output is only required for form components
- **Confirm:** Verify the file is a form component (has FormField/form()) before flagging missing save output.
- **Severity:** warning

---

## FE-FORM-003 -- Validators as factory functions

**What to check:** Validators must be function references or factory calls, not inline arrow functions.

**Scan:**

```
Grep pattern: "validators:\s*\[.*=>\s*"
     path:    frontend/libs
     output_mode: content
     glob:    "*.ts"
```

- **True positive:** `validators: [(control) => control.value ? null : { required: true }]` — inline arrow validator
- **False positive:** `validators: [Validators.required, myValidatorFn]` — function references, correct
- **False positive:** `validators: [minLength(3), maxLength(50)]` — factory calls, correct
- **Confirm:** Read the validators array to verify it contains inline arrows (violation) vs function references/factory calls (acceptable).
- **Severity:** info

---

## FE-FORM-004 -- Validation: blur, i18n, error below field

**What to check:** Every FormField with validators needs error display in the template using `| translate` and `ngx-error`.

**Scan 1 -- Find FormFields with validators:**

```
Grep pattern: "validators\s*:"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.ts"
```

**Scan 2 -- Check for ngx-error in corresponding templates:**

```
Grep pattern: "ngx-error|ngxError|\[err\]"
     path:    frontend/libs
     output_mode: files_with_matches
     glob:    "*.html"
```

- **Interpretation:** For each TypeScript file with validators, check if the corresponding HTML template has error display elements. Cross-reference by file naming convention (`.component.ts` -> `.component.html`).
- **True positive:** Form component with `validators: [Validators.required]` on a field but template has no error display for that field
- **False positive:** Form component with validators AND corresponding `<ngx-error>` or error div with `| translate` in template
- **Confirm:** Read the template file to verify error display elements exist for each validated field.
- **Severity:** info

Note: Full verification of field-to-error mapping requires reading both TS and HTML files. The Grep scan identifies candidates for manual review.
