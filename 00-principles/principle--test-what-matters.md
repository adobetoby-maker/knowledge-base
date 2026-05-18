# Test What Matters

## The Core Rule

Write tests for business logic, not for framework behavior. Test the rules the application enforces, not the implementation details of how it enforces them.

Test:
- Invoice total calculation logic
- Discount application rules
- Status transition validation (can't move from paid → draft)
- Auth guard behavior
- Data transformation functions

Don't write tests for:
- That React renders a `<div>`
- That Supabase returns data from the database
- That Next.js routing works
- That shadcn/ui Button renders a button element

## Identify What Actually Needs Tests

Ask: "If this logic had a bug, would I catch it before it affected a customer?"

High priority (test these):
- Money calculations (`lib/invoices/calculate.ts`)
- Validation logic (`lib/validation.ts`)
- Business rules (discounts, status, eligibility)
- Auth checks in server functions
- Data format transformations

Lower priority (framework handles it):
- UI rendering
- Database queries (integration tests handle this better)
- Next.js routes
- Component snapshots

## Unit Test Pattern (Vitest)

```typescript
// lib/invoices/calculate.test.ts
import { describe, it, expect } from 'vitest'
import { calculateInvoiceTotal, applyDiscount } from './calculate'

describe('calculateInvoiceTotal', () => {
  it('sums line items correctly', () => {
    const lineItems = [
      { quantity: 2, unitPriceCents: 5000 },  // $100
      { quantity: 1, unitPriceCents: 2500 },  // $25
    ]
    expect(calculateInvoiceTotal(lineItems)).toBe(12500)  // $125
  })
  
  it('returns 0 for empty line items', () => {
    expect(calculateInvoiceTotal([])).toBe(0)
  })
  
  it('rounds cents correctly for fractional quantities', () => {
    // 1.5 × $33.33 = $49.995 → $50.00
    expect(calculateInvoiceTotal([{ quantity: 1.5, unitPriceCents: 3333 }])).toBe(5000)
  })
})

describe('applyDiscount', () => {
  it('applies percentage discount', () => {
    expect(applyDiscount(10000, { type: 'percent', value: 10 })).toBe(9000)
  })
  
  it('applies flat discount', () => {
    expect(applyDiscount(10000, { type: 'flat', value: 500 })).toBe(9500)
  })
  
  it('does not allow discount to make total negative', () => {
    expect(applyDiscount(1000, { type: 'flat', value: 2000 })).toBe(0)
  })
})
```

## What Makes a Good Test

1. **Readable failure messages** — the test name says what should happen, not what the function does
   - BAD: `it('calls calculateTotal')`
   - GOOD: `it('includes tax when taxable is true')`

2. **One assertion per test** (roughly) — isolates what failed

3. **Tests edge cases explicitly** — empty inputs, boundary values, invalid states

4. **Doesn't test internal implementation** — if you rename a variable, tests shouldn't break

## Test Coverage Targets

Coverage number is not the goal — coverage of critical paths is.

Cover 100% of:
- Money calculation functions
- Business rule functions
- Auth validation

Don't chase coverage on:
- API route handlers (integration test those)
- React components (E2E test user flows)
- Utility functions that wrap stable libraries

## Running Tests

```bash
# jrs-auto-repair:
npx vitest run                           # all tests
npx vitest run lib/invoices/calculate    # specific file
npx vitest watch                         # watch mode during development
npx vitest --coverage                    # with coverage report
```
