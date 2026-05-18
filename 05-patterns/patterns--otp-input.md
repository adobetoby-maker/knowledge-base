# Pattern: OTP Input

## Overview

A segmented input for one-time passwords (2FA codes, verification PINs). Each digit appears in its own box. Users expect: auto-advance on type, paste support for the full code, backspace to go back.

## Component Implementation

```tsx
import { useRef, useState, KeyboardEvent, ClipboardEvent } from 'react'

interface OtpInputProps {
  length?: number
  onComplete: (code: string) => void
  disabled?: boolean
}

export function OtpInput({ length = 6, onComplete, disabled = false }: OtpInputProps) {
  const [values, setValues] = useState<string[]>(Array(length).fill(''))
  const inputs = useRef<(HTMLInputElement | null)[]>([])

  function focusNext(index: number) {
    inputs.current[index + 1]?.focus()
  }

  function focusPrev(index: number) {
    inputs.current[index - 1]?.focus()
  }

  function handleChange(index: number, value: string) {
    // Only accept digits
    if (value && !/^\d$/.test(value)) return

    const newValues = [...values]
    newValues[index] = value
    setValues(newValues)

    if (value) {
      focusNext(index)
      // Check completion
      if (index === length - 1 && newValues.every((v) => v !== '')) {
        onComplete(newValues.join(''))
      }
    }
  }

  function handleKeyDown(index: number, e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Backspace') {
      if (values[index]) {
        // Clear current field
        const newValues = [...values]
        newValues[index] = ''
        setValues(newValues)
      } else {
        // Move to previous
        focusPrev(index)
      }
    }

    if (e.key === 'ArrowLeft') focusPrev(index)
    if (e.key === 'ArrowRight') focusNext(index)
  }

  function handlePaste(e: ClipboardEvent<HTMLInputElement>) {
    e.preventDefault()
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '')
    const digits = pasted.slice(0, length).split('')

    const newValues = [...values]
    digits.forEach((d, i) => {
      newValues[i] = d
    })
    setValues(newValues)

    // Focus last filled input
    const lastIndex = Math.min(digits.length - 1, length - 1)
    inputs.current[lastIndex]?.focus()

    if (digits.length === length) {
      onComplete(newValues.join(''))
    }
  }

  function handleFocus(index: number) {
    // Select content on focus so typing replaces it
    inputs.current[index]?.select()
  }

  return (
    <div className="flex gap-2" role="group" aria-label="One-time password">
      {values.map((value, index) => (
        <input
          key={index}
          ref={(el) => { inputs.current[index] = el }}
          type="text"
          inputMode="numeric"
          pattern="\d*"
          maxLength={1}
          value={value}
          disabled={disabled}
          onChange={(e) => handleChange(index, e.target.value)}
          onKeyDown={(e) => handleKeyDown(index, e)}
          onPaste={handlePaste}
          onFocus={() => handleFocus(index)}
          aria-label={`Digit ${index + 1} of ${length}`}
          className={`h-12 w-10 rounded-lg border-2 text-center text-lg font-semibold transition-colors
            focus:border-blue-500 focus:outline-none
            ${value ? 'border-blue-300 bg-blue-50' : 'border-gray-200 bg-white'}
            ${disabled ? 'opacity-50 cursor-not-allowed' : ''}
          `}
        />
      ))}
    </div>
  )
}
```

## Usage

```tsx
function VerifyEmailPage() {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleComplete(code: string) {
    setLoading(true)
    setError(null)
    
    try {
      await verifyEmail(code)
      router.push('/dashboard')
    } catch {
      setError('Invalid code. Try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="space-y-4">
      <p className="text-sm text-gray-600">
        Enter the 6-digit code sent to your email
      </p>
      <OtpInput length={6} onComplete={handleComplete} disabled={loading} />
      {error && <p className="text-sm text-red-600">{error}</p>}
    </div>
  )
}
```

## Key Behaviors

**Paste handling**: Most users copy the code from SMS or email and paste the full 6 digits. The `onPaste` handler strips non-digits and fills all fields. This is the most important UX feature.

**Auto-advance**: After typing a digit, focus automatically moves to the next input. Never require the user to click each box.

**Backspace navigation**: If the current field is empty and backspace is pressed, move to the previous field. This is expected behavior.

**inputMode="numeric"**: On mobile, shows the numeric keypad. `type="text"` is better than `type="number"` because `type="number"` doesn't support `maxLength`.

**pattern="\d*"**: Hints to iOS Safari that numeric keyboard should be used (belts and suspenders with `inputMode`).

## Resend Code

Always include a resend option with rate limiting feedback:

```tsx
function ResendCode({ onResend }: { onResend: () => Promise<void> }) {
  const [countdown, setCountdown] = useState(60)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (countdown <= 0) return
    const t = setInterval(() => setCountdown((c) => c - 1), 1000)
    return () => clearInterval(t)
  }, [countdown])

  async function handleResend() {
    setLoading(true)
    await onResend()
    setCountdown(60)
    setLoading(false)
  }

  if (countdown > 0) {
    return <p className="text-sm text-gray-500">Resend code in {countdown}s</p>
  }

  return (
    <button onClick={handleResend} disabled={loading} className="text-sm text-blue-600 underline">
      {loading ? 'Sending...' : 'Resend code'}
    </button>
  )
}
```
