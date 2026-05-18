# Pattern: Password Input with Show/Hide Toggle

## Overview

The show/hide toggle on a password field is one of the most commonly misimplemented small components. The mistakes that matter: using a `<button>` without `type="button"` submits the form, using `autocomplete="off"` breaks password managers, and missing `aria-label` on the toggle makes it meaningless to screen reader users.

## Component

```tsx
import { useState, useId } from 'react'

interface PasswordInputProps {
  label: string
  value: string
  onChange: (value: string) => void
  autoComplete?: 'current-password' | 'new-password'
  error?: string
  disabled?: boolean
}

function PasswordInput({
  label,
  value,
  onChange,
  autoComplete = 'current-password',
  error,
  disabled,
}: PasswordInputProps) {
  const [visible, setVisible] = useState(false)
  const id = useId()
  const errorId = `${id}-error`

  return (
    <div>
      <label htmlFor={id}>{label}</label>
      <div style={{ position: 'relative' }}>
        <input
          id={id}
          type={visible ? 'text' : 'password'}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          autoComplete={autoComplete}
          disabled={disabled}
          aria-invalid={error ? 'true' : undefined}
          aria-describedby={error ? errorId : undefined}
        />
        <button
          type="button"
          onClick={() => setVisible((v) => !v)}
          aria-label={visible ? `Hide ${label}` : `Show ${label}`}
          aria-controls={id}
          disabled={disabled}
          tabIndex={0}
        >
          {visible ? <EyeOffIcon /> : <EyeIcon />}
        </button>
      </div>
      {error && <span id={errorId} role="alert">{error}</span>}
    </div>
  )
}
```

## Why Each Decision Matters

**`type="button"` is mandatory.** A `<button>` inside a `<form>` without `type="button"` defaults to `type="submit"`. The user clicks the eye icon to reveal their password and accidentally submits the form. This is a real UX bug that ships surprisingly often.

**Never use `autocomplete="off"`.** This is a cargo-cult pattern from a misguided attempt to prevent browsers from autofilling passwords. Password managers ignore `autocomplete="off"` anyway, and the legitimate browser autofill respects `autocomplete="current-password"` and `autocomplete="new-password"`. Use those values. `off` actively breaks password manager integration.

**`aria-label` must describe the action and context.** "Show" alone is useless to a screen reader user who may have multiple password fields on the page. "Show password" or "Show confirm password" is meaningful. Using the `label` prop dynamically generates this correctly.

**Switching `type` not `display`.** When the field is `type="password"`, the browser masks the characters. When it's `type="text"`, characters are visible. Do NOT move the value into a separate visible `<input type="text">` — that duplicates the field and breaks autofill completely.

**`aria-controls` links the toggle to the field.** Assistive technologies can announce "Show Password button controls password field" when this relationship is declared.

## In react-hook-form

```tsx
function LoginForm() {
  const { register, handleSubmit, watch } = useForm<{ email: string; password: string }>()
  const [visible, setVisible] = useState(false)

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input type="email" {...register('email')} />
      <div style={{ position: 'relative' }}>
        <input
          type={visible ? 'text' : 'password'}
          autoComplete="current-password"
          {...register('password', { required: true, minLength: 8 })}
        />
        <button type="button" onClick={() => setVisible(v => !v)} aria-label={visible ? 'Hide password' : 'Show password'}>
          {visible ? <EyeOffIcon /> : <EyeIcon />}
        </button>
      </div>
    </form>
  )
}
```

## Key Rules

- The toggle button **must** be `type="button"`. Missing this submits the form.
- Never set `autocomplete="off"` — use `"current-password"` or `"new-password"` instead.
- `aria-label` on the toggle must include the field name to be meaningful in multi-field forms.
- Toggle only the `type` attribute between `"password"` and `"text"`. Don't swap elements or duplicate the input.
- Keep the same DOM element for both states — swapping elements resets cursor position, selection, and autofill context.
- For new-password fields, use `autocomplete="new-password"` to let the browser offer to save the new credential.
