# Pattern: Number Input (Currency, Quantity, Percentage)

## What This Solves

Number inputs have type-specific formatting needs: currency inputs display "$" prefix and decimal formatting, quantity inputs enforce integer-only, percentage inputs cap at 100. The native `<input type="number">` is difficult to style and has UX issues (scroll changes value, mobile keyboard lacks decimals). Use a text input with controlled parsing.

## Currency Input

```tsx
// components/CurrencyInput.tsx
'use client'
import { useState, useCallback } from 'react'
import { Input } from '@/components/ui/input'
import { cn } from '@/lib/utils'

interface CurrencyInputProps {
  value: number           // Value in cents (integer)
  onChange: (cents: number) => void
  disabled?: boolean
  className?: string
}

export function CurrencyInput({ value, onChange, disabled, className }: CurrencyInputProps) {
  // Display value as dollars string; internal value is cents
  const [displayValue, setDisplayValue] = useState(() => (value / 100).toFixed(2))
  const [focused, setFocused] = useState(false)

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const raw = e.target.value.replace(/[^0-9.]/g, '')  // Strip non-numeric
    setDisplayValue(raw)

    const parsed = parseFloat(raw)
    if (!isNaN(parsed)) {
      onChange(Math.round(parsed * 100))  // Convert to cents, round to avoid float issues
    }
  }

  const handleBlur = () => {
    setFocused(false)
    const parsed = parseFloat(displayValue)
    if (!isNaN(parsed)) {
      setDisplayValue(parsed.toFixed(2))  // Format to 2 decimals on blur
    } else {
      setDisplayValue('0.00')
      onChange(0)
    }
  }

  return (
    <div className="relative">
      <span className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground text-sm pointer-events-none">
        $
      </span>
      <Input
        type="text"
        inputMode="decimal"
        value={focused ? displayValue : (value / 100).toFixed(2)}
        onChange={handleChange}
        onFocus={() => setFocused(true)}
        onBlur={handleBlur}
        disabled={disabled}
        className={cn('pl-7', className)}
        placeholder="0.00"
      />
    </div>
  )
}
```

## Quantity Input (Integer, Min/Max)

```tsx
// components/QuantityInput.tsx
'use client'

interface QuantityInputProps {
  value: number
  onChange: (n: number) => void
  min?: number
  max?: number
  step?: number
}

export function QuantityInput({ value, onChange, min = 1, max = 999, step = 1 }: QuantityInputProps) {
  const decrement = () => onChange(Math.max(min, value - step))
  const increment = () => onChange(Math.min(max, value + step))

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const raw = parseInt(e.target.value, 10)
    if (!isNaN(raw)) onChange(Math.min(max, Math.max(min, raw)))
  }

  return (
    <div className="flex items-center">
      <Button
        type="button"
        variant="outline"
        size="icon"
        className="h-8 w-8 rounded-r-none"
        onClick={decrement}
        disabled={value <= min}
      >
        <Minus className="h-3 w-3" />
      </Button>
      <input
        type="text"
        inputMode="numeric"
        value={value}
        onChange={handleChange}
        className="h-8 w-14 text-center border-y border-input bg-background text-sm focus:outline-none"
        aria-label="Quantity"
      />
      <Button
        type="button"
        variant="outline"
        size="icon"
        className="h-8 w-8 rounded-l-none"
        onClick={increment}
        disabled={value >= max}
      >
        <Plus className="h-3 w-3" />
      </Button>
    </div>
  )
}
```

## Percentage Input

```tsx
<div className="relative">
  <Input
    type="text"
    inputMode="decimal"
    value={displayValue}
    onChange={e => {
      const raw = e.target.value.replace(/[^0-9.]/g, '')
      const n = parseFloat(raw)
      if (!isNaN(n)) onChange(Math.min(100, Math.max(0, n)))
    }}
    className="pr-8"
    placeholder="0"
  />
  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground text-sm pointer-events-none">
    %
  </span>
</div>
```

## React Hook Form Integration

```tsx
import { Controller } from 'react-hook-form'

<Controller
  control={form.control}
  name="unit_price_cents"
  rules={{ required: true, min: { value: 1, message: 'Price must be greater than $0.00' } }}
  render={({ field, fieldState }) => (
    <div>
      <CurrencyInput
        value={field.value}
        onChange={field.onChange}
      />
      {fieldState.error && (
        <p className="text-sm text-destructive mt-1">{fieldState.error.message}</p>
      )}
    </div>
  )}
/>
```

## Zod Coercion for Form Values

When reading from HTML inputs (which produce strings), use coercion:

```ts
const LineItemSchema = z.object({
  description: z.string().min(1),
  quantity: z.coerce.number().int().positive(),
  unit_price_cents: z.coerce.number().int().nonnegative(),
})
```

`z.coerce.number()` handles `"5"` → `5` and `"5.0"` → `5`. Without coercion, an integer field receiving the string `"5"` fails validation.

## Key Rules

- Store prices as integers in cents — never floats
- Always use `inputMode="decimal"` or `inputMode="numeric"` for mobile keyboards
- `Math.round(dollars * 100)` when converting to cents — not `dollars * 100` (float imprecision)
- Never use `<input type="number">` for currency — scroll changes the value accidentally
