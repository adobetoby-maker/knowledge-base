# Pattern: Price Display

## Overview

Price display involves: locale-aware formatting, handling multiple currencies, showing original vs discounted prices, and safely storing and retrieving money values. The most common error is performing arithmetic on floats — always store money as integer cents (or smallest currency unit) and format at the display layer.

## Money Storage and Arithmetic

```ts
// BAD — float arithmetic errors
const price = 1.10 + 2.20  // 3.3000000000000003

// GOOD — store as cents, only format at display
const priceInCents = 330  // $3.30

function addPrices(a: number, b: number): number {
  return a + b  // Safe: integer math
}
```

Cents fit in a 32-bit integer for any realistic price. Use `BIGINT` in Postgres for prices over $21M or crypto amounts.

## Formatting with Intl.NumberFormat

```ts
// Cache formatters — they're expensive to construct
const formattersCache = new Map<string, Intl.NumberFormat>()

function getFormatter(currency: string, locale: string): Intl.NumberFormat {
  const key = `${locale}-${currency}`
  if (!formattersCache.has(key)) {
    formattersCache.set(key, new Intl.NumberFormat(locale, {
      style: 'currency',
      currency,
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }))
  }
  return formattersCache.get(key)!
}

function formatCents(cents: number, currency = 'USD', locale = 'en-US'): string {
  return getFormatter(currency, locale).format(cents / 100)
}

// Zero-decimal currencies — divide by 1 not 100
const ZERO_DECIMAL_CURRENCIES = new Set(['JPY', 'KRW', 'VND', 'IDR', 'HUF'])

function formatAmount(amount: number, currency: string, locale: string): string {
  const divisor = ZERO_DECIMAL_CURRENCIES.has(currency) ? 1 : 100
  return getFormatter(currency, locale).format(amount / divisor)
}

// Examples
formatCents(1999, 'USD', 'en-US')   // "$19.99"
formatCents(1999, 'EUR', 'de-DE')   // "19,99 €"
formatAmount(1999, 'JPY', 'ja-JP')  // "¥1,999"
```

## Price Component

```tsx
interface PriceProps {
  cents: number
  currency?: string
  locale?: string
  className?: string
}

export function Price({ cents, currency = 'USD', locale = 'en-US', className }: PriceProps) {
  return (
    <span className={className}>
      {formatCents(cents, currency, locale)}
    </span>
  )
}
```

## Discount Display

```tsx
interface DiscountedPriceProps {
  originalCents: number
  discountedCents: number
  currency?: string
  showSavings?: boolean
}

export function DiscountedPrice({
  originalCents,
  discountedCents,
  currency = 'USD',
  showSavings = true,
}: DiscountedPriceProps) {
  const discountPercent = Math.round((1 - discountedCents / originalCents) * 100)
  const savingsCents = originalCents - discountedCents

  return (
    <div className="flex items-baseline gap-2">
      <span className="text-2xl font-bold text-gray-900">
        {formatCents(discountedCents, currency)}
      </span>
      <span className="text-gray-500 line-through text-sm">
        {formatCents(originalCents, currency)}
      </span>
      {showSavings && (
        <span className="text-green-600 text-sm font-medium">
          Save {discountPercent}% ({formatCents(savingsCents, currency)})
        </span>
      )}
    </div>
  )
}
```

## Price Range (Variable Pricing)

```tsx
function PriceRange({ minCents, maxCents, currency = 'USD' }: { minCents: number; maxCents: number; currency?: string }) {
  if (minCents === maxCents) {
    return <Price cents={minCents} currency={currency} />
  }
  return (
    <span>
      {formatCents(minCents, currency)} – {formatCents(maxCents, currency)}
    </span>
  )
}
```

## Per-Unit Pricing

```tsx
function UnitPrice({ cents, unit, currency = 'USD' }: { cents: number; unit: string; currency?: string }) {
  return (
    <span>
      <span className="font-semibold">{formatCents(cents, currency)}</span>
      <span className="text-gray-500 text-sm"> / {unit}</span>
    </span>
  )
}

// Usage: <UnitPrice cents={1200} unit="month" />  → "$12.00 / month"
// Usage: <UnitPrice cents={50} unit="unit" />     → "$0.50 / unit"
```

## Server-Side Rendering

Prices formatted with `Intl.NumberFormat` can differ between server (Node.js) and client if locales differ. Two options:

1. Pass locale from `Accept-Language` header through to the component (consistent)
2. Format prices client-side only with `useEffect` (avoids hydration mismatch)

```tsx
function ClientPrice({ cents }: { cents: number }) {
  const [formatted, setFormatted] = useState<string | null>(null)
  useEffect(() => {
    setFormatted(formatCents(cents, 'USD', navigator.language))
  }, [cents])

  if (!formatted) return <span>{formatCents(cents, 'USD', 'en-US')}</span>
  return <span>{formatted}</span>
}
```

## Key Rules

- Store all money as integer cents in the database — never floats. `DECIMAL(10,2)` in Postgres is also safe but adds parsing overhead.
- `Intl.NumberFormat` handles thousands separators, decimal symbols, and currency placement automatically — never build your own formatter.
- JPY, KRW, VND, IDR, HUF, CLP, PYG are zero-decimal: `1999 JPY` = ¥1,999, not ¥19.99. Stripe's API uses this same convention.
- `line-through` on the original price (not hidden or dimmed only) communicates the discount clearly.
- For B2B products, show price excluding tax and note "+ VAT" — for consumer products, show tax-inclusive.
