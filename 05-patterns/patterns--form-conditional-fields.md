# Pattern: Form with Conditional Field Visibility

## Overview

Conditional fields — fields that appear or disappear based on other field values — have two failure modes: showing hidden fields to screen readers, and sending stale values from hidden fields to the server. Both are solved by *unregistering* fields when hidden, not just hiding them with CSS.

## The Core Problem with CSS-Only Hide

If a field is hidden with `display: none` but still registered with `react-hook-form`, its last value is included in the form submission. A user picks "Individual", the tax ID field hides, but if they previously typed a value into it, that value still submits. Unregistering removes it from the form state entirely.

## watch() for Reactive Visibility

```tsx
import { useForm, useWatch } from 'react-hook-form'

type FormValues = {
  accountType: 'individual' | 'business'
  companyName?: string
  taxId?: string
}

function AccountForm() {
  const { register, control, handleSubmit, formState: { errors }, unregister } = useForm<FormValues>()

  const accountType = useWatch({ control, name: 'accountType' })
  const showBusinessFields = accountType === 'business'

  // Unregister when hidden so values don't persist in form state
  useEffect(() => {
    if (!showBusinessFields) {
      unregister(['companyName', 'taxId'])
    }
  }, [showBusinessFields, unregister])

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <select {...register('accountType')}>
        <option value="individual">Individual</option>
        <option value="business">Business</option>
      </select>

      {showBusinessFields && (
        <>
          <input
            {...register('companyName', { required: 'Company name is required' })}
            aria-required="true"
          />
          {errors.companyName && <span role="alert">{errors.companyName.message}</span>}

          <input
            {...register('taxId', { required: 'Tax ID is required' })}
            aria-required="true"
          />
        </>
      )}
    </form>
  )
}
```

## Conditional Validation

Validation rules should only run when the field is visible. With unregistering this happens automatically — an unregistered field has no validation. But if keeping the field mounted (e.g., for animation), use `validate` with a context check:

```tsx
register('taxId', {
  validate: (value) => {
    if (accountType !== 'business') return true   // not applicable
    if (!value) return 'Tax ID is required'
    if (!/^\d{9}$/.test(value)) return 'Must be 9 digits'
    return true
  }
})
```

Avoid `required: accountType === 'business'` — this evaluates at registration time, not at validation time, so it won't update reactively.

## Accessibility: Removing from Tab Order

Hiding with `display: none` or conditional rendering removes the element from the DOM entirely, which is correct. `visibility: hidden` does not — the element is invisible but still focusable. CSS-only approaches using `opacity: 0` are worst — visible to screen readers AND focusable.

Rule: use conditional rendering (`{condition && <Field />}`) or `display: none`. Never use `visibility: hidden` or `opacity` for fields that should be logically absent.

When a field appears, move focus to it if the user triggered the show explicitly:

```tsx
const fieldRef = useRef<HTMLInputElement>(null)

useEffect(() => {
  if (showBusinessFields) {
    // Small delay for render to commit
    setTimeout(() => fieldRef.current?.focus(), 50)
  }
}, [showBusinessFields])
```

## Keeping Previous Values on Re-show

Sometimes users toggle back and forth and expect their typed value to persist. `unregister` destroys the value. To preserve it, use `keepValue: true`:

```ts
unregister('taxId', { keepValue: true })
```

But be aware: `keepValue: true` keeps the value in state even though the field is hidden. Only use this when re-showing the field is expected and the preserved value is harmless in submissions (handle server-side by ignoring irrelevant fields based on `accountType`).

## Key Rules

- Always unregister hidden fields (not CSS-hide) unless you explicitly want to preserve the value server-side.
- Use `useWatch` (or `watch()` inside render) to drive conditional rendering — not `getValues()` in render which doesn't subscribe to changes.
- Validation rules using closure values (like `accountType`) must be inside `validate` functions, not in the `required`/`pattern` shorthand which evaluates once at registration.
- Conditional rendering automatically handles tab order; `visibility: hidden` does not.
- When a field group appears, focus the first field so keyboard users know something changed.
