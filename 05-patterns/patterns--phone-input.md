# Pattern: Phone Input with Country Code

## Overview

International phone input with country code selector. Key challenge: phone number formatting varies by country — E.164 format (`+12025551234`) is the safe universal storage format. Display format (masked or spaced) is separate from stored format.

## E.164 Storage Rule

Always store phone numbers in E.164 format in the database, regardless of how they're displayed:

```ts
// Store: +12025551234
// Display: (202) 555-1234  or  +1 202-555-1234
// Never store: "202 555 1234" or "(202) 555-1234" — impossible to parse reliably later
```

## Using react-phone-number-input

```tsx
import PhoneInput from 'react-phone-number-input'
import 'react-phone-number-input/style.css'

function PhoneField({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  return (
    <PhoneInput
      international
      countryCallingCodeEditable={false}
      defaultCountry="US"
      value={value}
      onChange={val => onChange(val ?? '')}
      className="phone-input-wrapper"
    />
  )
}
```

`onChange` receives E.164 string or `undefined`. Store the E.164 value directly.

## Validation

```ts
import { isValidPhoneNumber, parsePhoneNumber } from 'libphonenumber-js'

function validatePhone(value: string): string | null {
  if (!value) return null  // Optional field — return null if empty ok
  if (!isValidPhoneNumber(value)) return 'Invalid phone number'
  return null
}

// Extract parts for display or messaging
const parsed = parsePhoneNumber('+12025551234')
parsed.country         // 'US'
parsed.nationalNumber  // '2025551234'
parsed.formatNational() // '(202) 555-1234'
parsed.formatInternational() // '+1 202 555 1234'
```

## Without a Library (Simple US-only)

For US-only forms where international support isn't needed:

```tsx
function USPhoneInput({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  function format(raw: string): string {
    const digits = raw.replace(/\D/g, '').slice(0, 10)
    if (digits.length < 4) return digits
    if (digits.length < 7) return `(${digits.slice(0, 3)}) ${digits.slice(3)}`
    return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`
  }

  function toE164(formatted: string): string {
    const digits = formatted.replace(/\D/g, '')
    return digits.length === 10 ? `+1${digits}` : ''
  }

  const [display, setDisplay] = useState(formatDisplay(value))

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const formatted = format(e.target.value)
    setDisplay(formatted)
    onChange(toE164(formatted))
  }

  return (
    <input
      type="tel"
      inputMode="numeric"
      value={display}
      onChange={handleChange}
      placeholder="(555) 555-5555"
      maxLength={14}
    />
  )
}
```

## Key Rules

- Store E.164 — parsing arbitrary national formats later is fragile and error-prone.
- `type="tel"` opens the numeric keyboard on mobile; add `inputMode="numeric"` for Android.
- Don't validate on every keystroke — only on blur or submit.
- If using Twilio or similar SMS, E.164 is required — surface this constraint to the form.
- For optional phone fields, don't store empty string — store `null` so you can `IS NULL` query.
