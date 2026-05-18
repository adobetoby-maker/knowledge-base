# Failure Patterns: Money Calculation Bugs

## The Root Cause

Floating-point arithmetic in JavaScript is imprecise. `0.1 + 0.2 !== 0.3`. Any financial calculation done in floats will eventually produce wrong answers.

```javascript
console.log(0.1 + 0.2)           // 0.30000000000000004
console.log(1.15 * 100)           // 114.99999999999999
console.log(Math.round(1.15 * 100))  // 115 — looks right but unreliable
console.log(1.005 * 1000)         // 1004.9999999999999
```

## The Fix: Integers Only

Store all money as integer cents. Never use floats for money.

```typescript
// WRONG — float math:
const total = lineItems.reduce((sum, item) => sum + item.price * item.quantity, 0)
const tax = total * 0.08

// CORRECT — integer cents:
const subtotalCents = lineItems.reduce((sum, item) => sum + item.priceCents * item.quantity, 0)
const taxCents = Math.round(subtotalCents * 0.08)  // round at the end, not intermediate
const totalCents = subtotalCents + taxCents
```

## Rounding Rules

Round once, at the final step:

```typescript
// WRONG — rounding intermediate values:
const price = Math.round(10.005 * 100)     // 1001
const discounted = Math.round(price * 0.9) // rounds again — double rounding

// CORRECT — round only the final result:
const priceRaw = 10.005
const discounted = priceRaw * 0.9          // 9.0045
const finalCents = Math.round(discounted * 100)  // 901 — rounded once
```

## Display vs Storage

```typescript
// Store as integer cents:
const priceCents = 1299  // $12.99

// Display as formatted currency:
function formatCurrency(cents: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(cents / 100)
}

formatCurrency(1299)  // "$12.99"
formatCurrency(100)   // "$1.00"
```

## Database Column Names

Use `_cents` suffix to make the integer nature explicit:

```sql
total_cents integer NOT NULL,           -- NOT total or total_amount
unit_price_cents integer NOT NULL,
discount_amount_cents integer DEFAULT 0
```

This prevents confusion — a developer reading `total_cents = 1299` immediately knows it's $12.99.

## Input → Cents Conversion

When reading from a form or external API that returns decimal dollars:

```typescript
function dollarsToCents(dollars: number | string): number {
  const parsed = typeof dollars === 'string' ? parseFloat(dollars) : dollars
  if (isNaN(parsed)) throw new Error('Invalid dollar amount')
  return Math.round(parsed * 100)
}

dollarsToCents('12.99')  // 1299
dollarsToCents(12.999)   // 1300 (rounded)
dollarsToCents('12.005') // 1201 (rounds up)
```

## Cents → Dollars Conversion (Display Only)

```typescript
function centsToDollars(cents: number): number {
  return cents / 100  // safe division — used for display only
}

// Type annotation reminds callers this is for display, not storage:
function formatAmount(cents: number): string {
  return `$${centsToDollars(cents).toFixed(2)}`
}
```

## Postgres Arithmetic

Postgres is safe for integer arithmetic, but watch for division:

```sql
-- Safe:
SELECT total_cents + tax_cents AS grand_total_cents FROM invoices;

-- Potential issue — integer division truncates:
SELECT total_cents / 100 AS total_dollars FROM invoices;  -- 199 cents → 1, not 1.99

-- Correct:
SELECT ROUND(total_cents / 100.0, 2) AS total_dollars FROM invoices;
-- OR: just keep everything in cents and format in application code
```
