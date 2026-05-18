# Pattern: Input Validation Inline

## Overview
Validating on every keystroke frustrates users mid-thought ("invalid email" before they've finished typing). Validating only on submit makes errors feel delayed. Blur-time validation is the sweet spot: wait for the user to indicate they're done with a field, then check. Server validation errors must appear in the same location and style as client errors — inconsistency causes confusion about which errors are "real."

## Implementation

### Custom Hook: useField
```typescript
interface FieldState {
  value: string;
  error: string | null;
  touched: boolean; // has the user blurred this field?
}

function useField(initialValue = '', validate?: (value: string) => string | null) {
  const [state, setState] = useState<FieldState>({
    value: initialValue,
    error: null,
    touched: false,
  });

  const onChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setState(prev => ({
      ...prev,
      value,
      // Clear error on change — but don't re-validate yet (wait for blur)
      error: prev.touched ? null : prev.error,
    }));
  };

  const onBlur = () => {
    const error = validate?.(state.value) ?? null;
    setState(prev => ({ ...prev, touched: true, error }));
  };

  // Set server error from outside the component
  const setError = (error: string | null) => {
    setState(prev => ({ ...prev, error, touched: true }));
  };

  return { value: state.value, error: state.error, onChange, onBlur, setError };
}
```

### Field Component
```tsx
interface FieldProps {
  id: string;
  label: string;
  type?: string;
  error?: string | null;
  required?: boolean;
  [key: string]: unknown; // input props passthrough
}

function Field({ id, label, error, required, ...inputProps }: FieldProps) {
  const errorId = `${id}-error`;

  return (
    <div className="field">
      <label htmlFor={id}>
        {label}
        {required && <span aria-hidden="true"> *</span>}
      </label>
      <input
        id={id}
        aria-invalid={!!error}
        aria-describedby={error ? errorId : undefined}
        aria-required={required}
        className={error ? 'input-error' : 'input'}
        {...inputProps}
      />
      {error && (
        <p id={errorId} className="field-error" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
```

### Form with Client + Server Validation
```tsx
function RegistrationForm() {
  const email = useField('', validateEmail);
  const password = useField('', validatePassword);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    // Final client validation before submit
    const emailError = validateEmail(email.value);
    const passwordError = validatePassword(password.value);
    if (emailError) { email.setError(emailError); return; }
    if (passwordError) { password.setError(passwordError); return; }

    try {
      await registerUser({ email: email.value, password: password.value });
    } catch (err) {
      // Server validation errors — same visual treatment as client errors
      if (err.code === 'EMAIL_TAKEN') {
        email.setError('This email is already registered. Try logging in instead.');
      } else {
        throw err; // let error boundary handle unexpected errors
      }
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      <Field
        id="email"
        label="Email"
        type="email"
        required
        value={email.value}
        onChange={email.onChange}
        onBlur={email.onBlur}
        error={email.error}
      />
      <Field
        id="password"
        label="Password"
        type="password"
        required
        value={password.value}
        onChange={password.onChange}
        onBlur={password.onBlur}
        error={password.error}
      />
      <button type="submit">Create account</button>
    </form>
  );
}
```

### Validators
```typescript
function validateEmail(value: string): string | null {
  if (!value) return 'Email is required';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) return 'Enter a valid email address';
  return null;
}

function validatePassword(value: string): string | null {
  if (!value) return 'Password is required';
  if (value.length < 8) return 'Password must be at least 8 characters';
  return null;
}
```

### CSS
```css
.input { border: 1px solid var(--border); }
.input:focus { border-color: var(--ring); outline: 2px solid var(--ring); }

/* Red border when invalid — but only after touched */
.input-error { border-color: var(--destructive); }
.input-error:focus { border-color: var(--destructive); outline-color: var(--destructive); }

/* Return to normal state as soon as error is cleared */
.field-error { color: var(--destructive); font-size: 0.75rem; margin-top: 4px; }
```

## Key Rules
- Validate on blur, not on keystroke — keystroke validation is too aggressive for most fields
- Clear the error immediately on change (after first touch) — don't make users re-blur to see if they fixed it
- Server validation errors appear in the same place, same red style as client errors — no modals, no banners
- `aria-invalid`, `aria-describedby`, and `role="alert"` on error messages — required for screen readers
- `noValidate` on the form tag — prevents browser's default validation UI from conflicting with yours
- Run a final client validation pass on submit — catches unfilled required fields that were never blurred
- Error message text explains the fix, not just the failure: "Enter a valid email address" vs "Invalid"
- Field returns to normal visual state as soon as the error is resolved — don't keep red border while user types
- Use `aria-required` not just `required` — both semantic meaning and behavior
- Never use alert() or toast for per-field validation errors — inline errors are always superior
