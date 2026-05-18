# Pattern: Input Mask

## Overview

Input masks format user input as they type: phone numbers, credit cards, dates, postal codes. The goal is to reduce validation errors and improve UX by formatting automatically. The key implementation decision: use a library (`react-input-mask`, `imask`) or a custom hook. For simple cases (phone, card), a custom hook is more lightweight.

## Custom Phone Mask Hook

```ts
function usePhoneMask(value: string, onChange: (v: string) => void) {
  function format(input: string): string {
    const digits = input.replace(/\D/g, '').slice(0, 10)
    if (digits.length <= 3) return digits
    if (digits.length <= 6) return `(${digits.slice(0, 3)}) ${digits.slice(3)}`
    return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`
  }

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const formatted = format(e.target.value)
    onChange(formatted)
  }

  return { value: format(value), onChange: handleChange }
}

// Usage
function PhoneInput({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  const masked = usePhoneMask(value, onChange)
  return (
    <input
      type="tel"
      inputMode="numeric"
      placeholder="(555) 555-5555"
      maxLength={14}
      {...masked}
    />
  )
}
```

## Credit Card Mask

```ts
function formatCreditCard(input: string): string {
  const digits = input.replace(/\D/g, '').slice(0, 16)
  // Group into 4-4-4-4
  return digits.match(/.{1,4}/g)?.join(' ') ?? digits
}

function getCreditCardType(number: string): 'visa' | 'mastercard' | 'amex' | 'unknown' {
  const digits = number.replace(/\D/g, '')
  if (/^4/.test(digits)) return 'visa'
  if (/^5[1-5]|^2[2-7]/.test(digits)) return 'mastercard'
  if (/^3[47]/.test(digits)) return 'amex'
  return 'unknown'
}

function CreditCardInput({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  const type = getCreditCardType(value)
  const maxLength = type === 'amex' ? 17 : 19  // AMEX: 4-6-5

  return (
    <div className="relative">
      <input
        type="text"
        inputMode="numeric"
        placeholder="1234 5678 9012 3456"
        maxLength={maxLength}
        value={formatCreditCard(value)}
        onChange={e => onChange(e.target.value.replace(/\D/g, ''))}
      />
      {type !== 'unknown' && (
        <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-500">
          {type.toUpperCase()}
        </span>
      )}
    </div>
  )
}
```

## Expiry Date Mask (MM/YY)

```ts
function formatExpiry(input: string): string {
  const digits = input.replace(/\D/g, '').slice(0, 4)
  if (digits.length <= 2) return digits
  return `${digits.slice(0, 2)}/${digits.slice(2)}`
}

function ExpiryInput({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  return (
    <input
      type="text"
      inputMode="numeric"
      placeholder="MM/YY"
      maxLength={5}
      value={formatExpiry(value)}
      onChange={e => onChange(e.target.value)}
    />
  )
}
```

## Using react-imask for Complex Masks

```tsx
import { IMaskInput } from 'react-imask'

// Date mask with validation
function DateInput({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  return (
    <IMaskInput
      mask="MM/DD/YYYY"
      blocks={{
        MM: { mask: IMask.MaskedRange, from: 1, to: 12, maxLength: 2 },
        DD: { mask: IMask.MaskedRange, from: 1, to: 31, maxLength: 2 },
        YYYY: { mask: IMask.MaskedRange, from: 2020, to: 2099, maxLength: 4 },
      }}
      value={value}
      onAccept={onChange}
      placeholder="MM/DD/YYYY"
      className="input"
    />
  )
}

// Currency mask
<IMaskInput
  mask={Number}
  scale={2}
  signed={false}
  thousandsSeparator=","
  radix="."
  mapToRadix={['.']}
  normalizeZeros={true}
  padFractionalZeros={true}
  value={String(amountInDollars)}
  onAccept={(value) => setAmount(parseFloat(value.replace(/,/g, '')) || 0)}
/>
```

## Storing Masked vs Raw Values

```ts
// Store the raw (unmasked) value, display the masked value
const [rawPhone, setRawPhone] = useState('')  // "5551234567"
const displayPhone = formatPhone(rawPhone)    // "(555) 123-4567"

// In form submission
const formData = {
  phone: rawPhone,  // Store digits only
}
```

Always store unmasked (digits-only) values in the database. The mask is a display/entry format, not a storage format.

## Key Rules

- `inputMode="numeric"` shows the numeric keyboard on mobile for numeric inputs — better UX than `type="text"` alone.
- Store raw values (digits only) in state and DB — never store the formatted string. Format only for display.
- Custom hooks are appropriate for simple masks (phone, credit card) — use `react-imask` for date masks or currency where range validation matters.
- `maxLength` on the input prevents users from typing beyond the mask length — set it to the formatted string length, not digit count.
- Never validate credit card numbers client-side alone — use Stripe Elements which handles both masking and validation securely.
