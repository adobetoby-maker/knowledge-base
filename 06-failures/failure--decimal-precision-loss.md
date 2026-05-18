# Failure: Decimal Precision Loss

## Overview
JavaScript uses IEEE 754 double-precision floating-point for all numbers. This binary representation cannot exactly represent most decimal fractions. The result: `0.1 + 0.2 === 0.30000000000000004`, not `0.3`. For currency, this is not a rounding curiosity — it's a billing defect that accumulates across millions of transactions, breaks comparison logic, and causes audit failures.

## The Core Problem

```javascript
// Seemingly simple arithmetic — all wrong
0.1 + 0.2              // 0.30000000000000004
1.005.toFixed(2)       // "1.00" not "1.01" — surprise rounding
0.1 + 0.2 === 0.3      // false
19.99 * 100            // 1998.9999999999998, not 1999
(1.275 * 100).toFixed(2) // "127.50" or "127.49" — platform-dependent

// Real billing consequences
const total = items.reduce((sum, item) => sum + item.price, 0);
// After 30 items at $9.99: sum may be $299.69999... instead of $299.70
```

## The Fix: Store and Calculate in Integer Cents

The only safe approach for money: store as integers (whole cents), display by dividing.

```typescript
// Storage: always in cents (integer)
interface LineItem {
  priceInCents: number;   // 999 = $9.99
  quantity: number;
}

// Calculation: integer arithmetic only
function calculateSubtotal(items: LineItem[]): number {
  return items.reduce((sum, item) => sum + item.priceInCents * item.quantity, 0);
}

// Tax: round at calculation time, not display time
function applyTax(amountCents: number, taxRate: number): number {
  return Math.round(amountCents * taxRate);
}

// Display: only divide when rendering to user
function formatCents(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`;
}
```

Integer arithmetic is exact. `999 * 3 = 2997` exactly, every time.

## When Integers Aren't Enough: Decimal.js

For financial systems requiring fractional cents (interest calculations, currency conversion, per-unit pricing with 4 decimal places):

```typescript
import Decimal from 'decimal.js';

const price = new Decimal('9.99');
const tax = new Decimal('0.08875');  // 8.875% — exact string representation
const total = price.mul(tax.plus(1)).toDecimalPlaces(2);
// total.toString() === "10.88" — exactly correct
```

Key: always initialize Decimal from strings, never from float literals:
```typescript
new Decimal(0.1)        // WRONG — 0.1 is already imprecise before Decimal sees it
new Decimal('0.1')      // Correct — string is parsed exactly
```

## The `toFixed` Trap

`toFixed` returns a **string**, and its rounding behavior is implementation-defined for .5 cases:

```javascript
(1.005).toFixed(2)   // "1.00" in most environments (banker's rounding)
(1.015).toFixed(2)   // "1.01" sometimes, "1.02" in others
typeof (1.005).toFixed(2)  // "string" — parseFloat of this is back to imprecise
```

Never use `toFixed` for calculations — only for display, and only after rounding with `Math.round`.

## parseFloat on Currency Input

```typescript
// User types "$9.99" into a form
const raw = "$9.99";
const price = parseFloat(raw.replace('$', ''));  // 9.99 — already imprecise float
// Instead:
const priceInCents = Math.round(parseFloat(raw.replace('$', '')) * 100);  // 999 — exact
```

Parse user input to cents immediately, at the boundary. Never store or calculate with the float.

## Database Storage

```sql
-- Wrong: FLOAT or DOUBLE PRECISION stores imprecisely
price FLOAT

-- Correct: NUMERIC/DECIMAL stores exactly
price NUMERIC(10, 2)

-- Or: store as integer cents
price_cents INTEGER
```

PostgreSQL's `NUMERIC` type uses decimal arithmetic — exact. `FLOAT` and `DOUBLE PRECISION` use binary floating-point — imprecise.

## Key Rules
- Store money as integer cents in both application code and database
- Never use `parseFloat` on currency values; parse to cents at user input boundaries
- `toFixed()` returns a string and has non-deterministic rounding — use only for display
- Round at the point of calculation (tax, discount), not at storage or retrieval
- For complex financial math (interest, exchange rates), use `decimal.js` initialized from strings
- `NUMERIC(10,2)` in PostgreSQL, not `FLOAT` or `DOUBLE PRECISION`
