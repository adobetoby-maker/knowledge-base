# Pattern: Async Field Validation

## Overview
Async validation (checking if a username is taken, email exists, coupon is valid) requires a different UX pattern from synchronous validation. The user needs feedback that a check is running, then a clear result. Debouncing prevents a server round-trip on every keystroke. Aborting previous requests on new input prevents stale results from overwriting fresh ones — the classic race condition in async validation. Blocking form submission on network failure is wrong; always validate again on submit so a network glitch doesn't permanently lock the form.

## Implementation

### Async Validation Hook
```tsx
import { useCallback, useEffect, useRef, useState } from 'react'

type ValidationState = 'idle' | 'checking' | 'valid' | 'invalid' | 'error'

interface AsyncValidationResult {
  state: ValidationState
  message: string | null
}

interface UseAsyncValidationOptions {
  validate: (value: string) => Promise<{ valid: boolean; message?: string }>
  debounceMs?: number
  minLength?: number // Don't validate until value reaches this length
}

function useAsyncValidation({
  validate,
  debounceMs = 500,
  minLength = 1,
}: UseAsyncValidationOptions) {
  const [result, setResult] = useState<AsyncValidationResult>({
    state: 'idle',
    message: null,
  })

  const abortRef = useRef<AbortController | null>(null)
  const debounceRef = useRef<ReturnType<typeof setTimeout>>()
  const lastValueRef = useRef<string>('')

  const check = useCallback(
    (value: string) => {
      lastValueRef.current = value

      // Reset on empty
      if (!value || value.length < minLength) {
        setResult({ state: 'idle', message: null })
        return
      }

      // Abort previous in-flight request
      abortRef.current?.abort()

      // Debounce
      clearTimeout(debounceRef.current)
      setResult({ state: 'idle', message: null }) // Clear previous result immediately on type

      debounceRef.current = setTimeout(async () => {
        const controller = new AbortController()
        abortRef.current = controller

        setResult({ state: 'checking', message: null })

        try {
          const outcome = await validate(value)

          // Guard: ignore stale results if value has since changed
          if (lastValueRef.current !== value) return

          setResult({
            state: outcome.valid ? 'valid' : 'invalid',
            message: outcome.message ?? null,
          })
        } catch (err) {
          if ((err as Error).name === 'AbortError') return // Intentionally aborted — ignore
          // Network/server error — don't block the user
          setResult({ state: 'error', message: null })
        }
      }, debounceMs)
    },
    [validate, debounceMs, minLength]
  )

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      clearTimeout(debounceRef.current)
      abortRef.current?.abort()
    }
  }, [])

  return { result, check }
}
```

### Field Component with Async Validation
```tsx
function AsyncValidatedInput({
  label,
  name,
  validate,
  placeholder,
}: {
  label: string
  name: string
  validate: (value: string) => Promise<{ valid: boolean; message?: string }>
  placeholder?: string
}) {
  const [value, setValue] = useState('')
  const { result, check } = useAsyncValidation({ validate, debounceMs: 500, minLength: 2 })

  // Also validate on blur (catches paste without keystroke)
  const handleBlur = () => {
    if (value.length >= 2) check(value)
  }

  const statusIcon = {
    idle: null,
    checking: <Spinner className="w-4 h-4 text-gray-400 animate-spin" aria-hidden="true" />,
    valid: (
      <svg aria-hidden="true" className="w-4 h-4 text-green-500" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
      </svg>
    ),
    invalid: (
      <svg aria-hidden="true" className="w-4 h-4 text-red-500" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
      </svg>
    ),
    error: null, // Network error — show nothing, don't block
  }[result.state]

  const inputBorder = {
    idle: 'border-gray-300',
    checking: 'border-gray-300',
    valid: 'border-green-400',
    invalid: 'border-red-400',
    error: 'border-gray-300',
  }[result.state]

  const fieldId = `field-${name}`
  const descId = `${fieldId}-desc`

  return (
    <div>
      <label htmlFor={fieldId} className="block text-sm font-medium text-gray-700 mb-1">
        {label}
      </label>
      <div className="relative">
        <input
          id={fieldId}
          name={name}
          type="text"
          value={value}
          placeholder={placeholder}
          onChange={(e) => {
            setValue(e.target.value)
            check(e.target.value)
          }}
          onBlur={handleBlur}
          aria-describedby={result.message ? descId : undefined}
          aria-invalid={result.state === 'invalid'}
          className={`w-full border rounded-md px-3 py-2 pr-10 text-sm ${inputBorder}`}
        />
        {statusIcon && (
          <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center">
            {result.state === 'checking' && (
              <span className="sr-only" aria-live="polite">Checking availability...</span>
            )}
            {statusIcon}
          </div>
        )}
      </div>

      {result.message && (
        <p
          id={descId}
          className={`text-xs mt-1 ${result.state === 'invalid' ? 'text-red-500' : 'text-green-600'}`}
          role="alert"
          aria-live="polite"
        >
          {result.message}
        </p>
      )}
    </div>
  )
}
```

### Validate on Submit Too
```tsx
// Never rely solely on the blur/debounce async check
// Always re-validate on form submit (network may have been unavailable during field edit)
async function handleSubmit(e: React.FormEvent) {
  e.preventDefault()
  const username = formData.username

  // Re-check synchronously before proceeding
  try {
    const result = await checkUsernameAvailable(username)
    if (!result.valid) {
      setError('username', result.message ?? 'Username is not available')
      return
    }
  } catch {
    // If server is unreachable on submit, allow submission anyway
    // The server will return a proper error on the POST request
  }

  await submitForm(formData)
}
```

## Key Rules
- Debounce 500ms from the last keystroke — 300ms is too eager for async network calls
- Abort the previous request before starting a new one — use `AbortController` and ignore `AbortError` in the catch block
- Check `lastValueRef.current !== value` after awaiting — guards against stale results replacing fresh results
- Never block form submission on network failure during async validation — the field check is a UX hint, not the source of truth
- Validate again on form submit — the blur-time check may be stale if the user takes a long time filling the rest of the form
- Show spinner during check, checkmark on valid, error icon on invalid — all three states must be visually distinct
- `aria-invalid` on the input, `role="alert"` + `aria-live="polite"` on the message — screen readers announce the result
- Minimum length check before triggering validation — don't fire a server request for a 1-character username
