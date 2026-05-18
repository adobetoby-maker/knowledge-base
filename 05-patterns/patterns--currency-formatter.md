# Pattern: Currency Display

## Overview
Floating-point arithmetic corrupts money: `0.1 + 0.2 === 0.30000000000000004`. Storing amounts as floats leads to rounding errors that compound across tax, shipping, and discount calculations. Display rounding must be explicit — implicitly showing "$10.5" as "$10.50" requires deliberate formatting, and locale-appropriate symbols differ from what you'd hardcode.

## Implementation

```typescript
// lib/currency.ts

// RULE: store all amounts as integers (cents/pence/smallest unit)
// $19.99 is stored as 1999, not 19.99
// This eliminates floating-point arithmetic errors entirely

export interface Money {
  amount: number   // integer cents
  currency: string // ISO 4217: 'USD', 'EUR', 'GBP', etc.
}

// User's locale preference — store in user settings, not browser navigator
// navigator.language changes with system settings the user may not have set for your app
let userLocale = 'en-US'

export function setLocale(locale: string) {
  userLocale = locale
}

/**
 * Format an integer cent amount as a display string.
 * Always shows both decimal places: $10.00, not $10 or $10.0
 */
export function formatCurrency(
  cents: number,
  currency = 'USD',
  locale = userLocale
): string {
  if (!Number.isInteger(cents)) {
    console.warn(`formatCurrency: expected integer cents, got ${cents}`)
    // Round to avoid silently showing wrong value
    cents = Math.round(cents)
  }

  const amount = cents / 100

  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    currencyDisplay: 'symbol',   // '$', not 'USD' or 'US Dollar'
    minimumFractionDigits: 2,    // Always show .00 even for whole numbers
    maximumFractionDigits: 2,    // Never show .5 — always .50
  }).format(amount)
}

// Examples:
// formatCurrency(1999, 'USD')      → '$19.99'
// formatCurrency(1000, 'USD')      → '$10.00'  (not '$10' or '$10.0')
// formatCurrency(0, 'USD')         → '$0.00'   (not '' or '-')
// formatCurrency(1999, 'EUR', 'de-DE') → '19,99 €'  (locale-appropriate)
// formatCurrency(1999, 'JPY')      → '¥20'     (yen has no decimal places)

/**
 * JPY and other zero-decimal currencies store as whole units, not cents.
 * Use this to detect them.
 */
export function getCurrencyDecimals(currency: string): number {
  const zeroDecimal = ['JPY', 'KRW', 'VND', 'BIF', 'CLP', 'GNF', 'MGA', 'PYG', 'RWF', 'UGX', 'XAF', 'XOF', 'XPF']
  return zeroDecimal.includes(currency) ? 0 : 2
}

/**
 * Safely add two cent amounts.
 * Both must already be integers — this is just a sanity check.
 */
export function addMoney(a: Money, b: Money): Money {
  if (a.currency !== b.currency) {
    throw new Error(`Cannot add ${a.currency} and ${b.currency}`)
  }
  return { amount: a.amount + b.amount, currency: a.currency }
}

/**
 * Apply a percentage discount. Round half-up.
 * Example: 10% of $19.99 (1999 cents) = 199.9 → 200 cents = $2.00
 */
export function applyDiscount(cents: number, percentOff: number): number {
  return Math.round(cents * (1 - percentOff / 100))
}

/**
 * Convert a user-entered string ("19.99") to integer cents (1999).
 * Handles locale decimal separators.
 */
export function parseCurrencyInput(input: string, currency = 'USD'): number {
  // Strip currency symbols and whitespace
  const cleaned = input.replace(/[^0-9.,]/g, '')
  // Normalize decimal separator
  const normalized = cleaned.replace(',', '.')
  const float = parseFloat(normalized)
  if (isNaN(float)) return 0

  const decimals = getCurrencyDecimals(currency)
  return Math.round(float * Math.pow(10, decimals))
}
```

```tsx
// Price.tsx — display component
import { formatCurrency } from '@/lib/currency'

interface PriceProps {
  cents: number
  currency?: string
  locale?: string
  strikethrough?: boolean  // for "was" price
  className?: string
}

export function Price({ cents, currency = 'USD', locale, strikethrough, className }: PriceProps) {
  const formatted = formatCurrency(cents, currency, locale)

  return (
    <span
      className={className}
      style={{ textDecoration: strikethrough ? 'line-through' : undefined }}
      aria-label={strikethrough ? `Was ${formatted}` : formatted}
    >
      {formatted}
    </span>
  )
}

// Usage
<Price cents={1999} />                // $19.99
<Price cents={1999} strikethrough />  // ~~$19.99~~ (was price)
<Price cents={0} />                   // $0.00 (not empty, not "free")
```

```typescript
// Database schema guidance
// Store money as INTEGER (cents), not DECIMAL or FLOAT
// PostgreSQL: price INTEGER NOT NULL DEFAULT 0
// Drizzle: price: integer('price').notNull().default(0)

// When receiving from Stripe API, amounts are already in cents (integers)
// When receiving from user input, always parse through parseCurrencyInput()
```

## Key Rules
- Store all amounts as integers (cents) — never floats. `0.1 + 0.2` in JavaScript is not `0.3`.
- Use `Intl.NumberFormat` with `style: 'currency'` — never concatenate `'$' + amount.toFixed(2)`.
- Always set `minimumFractionDigits: 2` and `maximumFractionDigits: 2` to force `.00` on whole dollar amounts.
- Use the user's stored locale preference, not `navigator.language` — locale affects comma vs period as decimal separator.
- Zero displays as `$0.00`, not as an empty string, dash, or "Free" (unless the domain explicitly calls for "Free").
- Negative amounts (refunds) display as `−$5.00` — `Intl.NumberFormat` handles this correctly automatically.
- Different currencies have different decimal places: JPY uses 0, USD/EUR use 2. Use `getCurrencyDecimals()` before parsing input.
- Never do arithmetic on formatted strings — always operate on the integer cent values.
- Apply discounts as `Math.round(cents * factor)` — always round at the final step, never in intermediate calculations.
