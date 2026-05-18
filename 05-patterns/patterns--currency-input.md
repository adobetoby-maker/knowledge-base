# Pattern: Currency Input

## Overview

Currency inputs look simple but have several failure modes: formatting while typing breaks cursor position, storing display strings causes floating-point rounding errors, and locale-aware separators (`,` vs `.`) break on international deployments. The correct mental model: store raw cents as an integer, display formatted strings, format only on blur.

## Core Principle: Store Cents, Not Dollars

```ts
// WRONG — floating point rounding
const price = 29.99  // may become 29.989999999...

// RIGHT — store as integer cents
const priceInCents = 2999
```

Never store `"$29.99"` or `29.99` in state. Convert to cents on input, back to formatted string on display.

## Implementation

```tsx
import { useState, useRef } from 'react'

type CurrencyInputProps = {
  valueInCents: number
  onChange: (cents: number) => void
  currency?: string
  locale?: string
  max?: number  // max cents
  disabled?: boolean
  label: string
}

export function CurrencyInput({
  valueInCents,
  onChange,
  currency = 'USD',
  locale = 'en-US',
  max,
  disabled,
  label,
}: CurrencyInputProps) {
  // Raw string while user is typing — don't format mid-type
  const [rawInput, setRawInput] = useState('')
  const [isFocused, setIsFocused] = useState(false)

  const formatter = new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
  })

  // Display value: raw string while editing, formatted when blurred
  const displayValue = isFocused
    ? rawInput
    : valueInCents === 0 ? '' : formatter.format(valueInCents / 100)

  function handleFocus() {
    setIsFocused(true)
    // Pre-fill with decimal number for editing
    setRawInput(valueInCents > 0 ? (valueInCents / 100).toFixed(2) : '')
  }

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    // Allow only digits and one decimal separator
    const val = e.target.value.replace(/[^0-9.]/g, '')
    setRawInput(val)
  }

  function handleBlur() {
    setIsFocused(false)
    const parsed = parseFloat(rawInput)

    if (isNaN(parsed) || rawInput === '') {
      onChange(0)
      return
    }

    // Convert to cents, round to avoid floating point errors
    let cents = Math.round(parsed * 100)

    if (max !== undefined) {
      cents = Math.min(cents, max)
    }

    onChange(cents)
    setRawInput('')
  }

  return (
    <div className="currency-input-wrapper">
      <label htmlFor="currency-field">{label}</label>
      <div className="input-with-symbol">
        <span aria-hidden="true" className="currency-symbol">
          {/* Get symbol from locale without full format */}
          {new Intl.NumberFormat(locale, { style: 'currency', currency })
            .formatToParts(0)
            .find(p => p.type === 'currency')?.value}
        </span>
        {disabled ? (
          <span className="read-only-value">
            {formatter.format(valueInCents / 100)}
          </span>
        ) : (
          <input
            id="currency-field"
            type="text"
            inputMode="decimal"  // mobile: show numeric + decimal keyboard
            value={displayValue}
            onFocus={handleFocus}
            onChange={handleChange}
            onBlur={handleBlur}
            aria-label={label}
            aria-describedby="currency-hint"
          />
        )}
      </div>
      {max !== undefined && (
        <span id="currency-hint" className="hint">
          Max: {formatter.format(max / 100)}
        </span>
      )}
    </div>
  )
}
```

## Why Format on Blur, Not on Type

Formatting mid-type causes cursor jumping. If the user types `1234` and you format to `$1,234.00` after every keystroke, the cursor lands after the `$` sign. React's synthetic events and controlled inputs can't reliably preserve cursor position through string transformations that change string length. Blur-only formatting sidesteps this entirely.

## Locale-Aware Decimal Separator

Germany uses `,` as decimal, `.` as thousands. `Intl.NumberFormat` handles display correctly. For input parsing, the safe approach is: strip everything except digits and the last occurrence of `.` or `,`, then normalize to `.` before `parseFloat`:

```ts
function parseLocaleNumber(str: string, locale: string): number {
  const parts = new Intl.NumberFormat(locale).formatToParts(1.1)
  const decimalChar = parts.find(p => p.type === 'decimal')?.value ?? '.'
  const cleaned = str
    .replace(new RegExp(`[^\\d${decimalChar}]`, 'g'), '')
    .replace(decimalChar, '.')
  return parseFloat(cleaned)
}
```

## Disabled State: Render Span, Not Input

A disabled `<input>` looks different across browsers and still receives tab focus in some implementations. For read-only display, render a `<span>` with the formatted value — it's simpler, consistent, and not focusable.

## Key Rules

- Store cents as integers — floating-point math on currency amounts accumulates rounding errors
- Format only on blur — mid-type formatting breaks cursor position in controlled inputs
- Use `inputMode="decimal"` — shows the right keyboard on iOS/Android (numeric + decimal point)
- Extract currency symbol via `Intl.NumberFormat.formatToParts` — don't hardcode `$`
- Render `<span>` for disabled state — not a disabled input, which has inconsistent browser behavior
- Validate max in cents on blur, not on every keystroke — prevents jarring mid-type interruptions
- `Math.round(parsed * 100)` not `parseInt(parsed * 100)` — rounding avoids 0.1 + 0.2 = 0.30000004 issues
