# Testing Strategy

## Test What Matters

The goal is confidence that the system works, not a coverage number. Write tests for:
- Business logic with multiple branches (invoice calculation, auth permission checks)
- Functions where bugs would cost money or trust (payment processing, data mutations)
- Regression traps (bugs that were found and fixed — add a test)

Skip tests for:
- Simple pass-through functions (`return data.items`)
- Framework behavior (React rendering, Next.js routing)
- Third-party library behavior

## Test Pyramid for This Stack

```
         E2E Tests (few)
        /              \
       Playwright        
      /                  \
    Integration Tests (some)
   /                      \
  Route Handlers          Server Actions
 /                          \
Unit Tests (many)
|
Business logic, utilities, calculation functions
```

## Unit Tests with Vitest (jrs-auto-repair)

```bash
# Run all tests
npm run test
npx vitest run

# Run a single file
npx vitest run lib/invoices/calculate.test.ts

# Watch mode during development
npx vitest
```

```typescript
// lib/invoices/calculate.test.ts
import { describe, it, expect } from 'vitest'
import { calculateInvoiceTotal, applyDiscount } from './calculate'

describe('calculateInvoiceTotal', () => {
  it('sums line items', () => {
    const total = calculateInvoiceTotal([
      { description: 'Oil change', amount: 45.00 },
      { description: 'Labor', amount: 80.00 },
    ])
    expect(total).toBe(125.00)
  })

  it('handles empty items', () => {
    expect(calculateInvoiceTotal([])).toBe(0)
  })

  it('rounds to 2 decimal places', () => {
    const total = calculateInvoiceTotal([{ description: 'Part', amount: 10.555 }])
    expect(total).toBe(10.56)
  })
})

describe('applyDiscount', () => {
  it('applies percentage discount', () => {
    expect(applyDiscount(100, { type: 'percent', value: 20 })).toBe(80)
  })

  it('applies flat discount', () => {
    expect(applyDiscount(100, { type: 'flat', value: 15 })).toBe(85)
  })

  it('does not go below 0', () => {
    expect(applyDiscount(10, { type: 'flat', value: 50 })).toBe(0)
  })
})
```

## Integration Tests for Route Handlers

Test the full Route Handler including auth and database interaction using a test Supabase project:

```typescript
// lib/api/invoices.integration.test.ts
import { describe, it, expect, beforeAll } from 'vitest'
import { createAdminClient } from '@/lib/supabase/admin'

describe('GET /api/admin/invoices', () => {
  let testInvoiceId: string

  beforeAll(async () => {
    // Seed a test invoice
    const supabase = createAdminClient()
    const { data } = await supabase
      .from('invoices')
      .insert({ number: 'TEST-001', total: 100, status: 'pending' })
      .select()
      .single()
    testInvoiceId = data!.id
  })

  it('returns invoices for admin', async () => {
    const response = await fetch('http://localhost:3000/api/admin/invoices', {
      headers: { Cookie: 'admin_session=valid_test_session' },
    })
    expect(response.status).toBe(200)
    const data = await response.json()
    expect(Array.isArray(data.invoices)).toBe(true)
  })

  it('rejects unauthenticated requests', async () => {
    const response = await fetch('http://localhost:3000/api/admin/invoices')
    expect(response.status).toBe(401)
  })
})
```

## Mocking in Vitest

```typescript
import { vi } from 'vitest'

// Mock a module
vi.mock('@/lib/supabase/server', () => ({
  createClient: vi.fn(() => ({
    from: vi.fn().mockReturnValue({
      select: vi.fn().mockReturnValue({
        eq: vi.fn().mockResolvedValue({ data: mockData, error: null }),
      }),
    }),
  })),
}))

// Mock a specific function
vi.spyOn(emailService, 'sendEmail').mockResolvedValue({ success: true })

// Reset between tests
beforeEach(() => { vi.clearAllMocks() })
```

## Test File Organization

```
lib/
  invoices/
    calculate.ts           # implementation
    calculate.test.ts      # tests live next to implementation
  auth/
    permissions.ts
    permissions.test.ts
```

Co-locate tests with the code they test. Don't create a separate `__tests__` directory.

## What NOT to Test

```typescript
// DON'T test framework behavior
it('renders a div', () => {
  render(<InvoiceRow invoice={invoice} />)
  expect(document.querySelector('div')).toBeTruthy()
})

// DO test business logic
it('shows overdue badge when invoice is past due date', () => {
  const overdueInvoice = { ...invoice, dueDate: '2020-01-01', status: 'pending' }
  render(<InvoiceRow invoice={overdueInvoice} />)
  expect(screen.getByText('Overdue')).toBeTruthy()
})
```

## Test Data

Use factories for test data to avoid brittle test setup:
```typescript
// test/factories.ts
export function makeInvoice(overrides: Partial<Invoice> = {}): Invoice {
  return {
    id: 'test-invoice-id',
    number: 'INV-001',
    status: 'pending',
    total: 100,
    customer_name: 'Test Customer',
    created_at: new Date().toISOString(),
    ...overrides,
  }
}
```

## Running Tests in CI

```yaml
# .github/workflows/test.yml
- name: Run tests
  run: npm run test
  env:
    NEXT_PUBLIC_SUPABASE_URL: ${{ secrets.TEST_SUPABASE_URL }}
    NEXT_PUBLIC_SUPABASE_ANON_KEY: ${{ secrets.TEST_SUPABASE_ANON_KEY }}
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.TEST_SERVICE_ROLE_KEY }}
```

Use a separate Supabase project for tests — never run tests against production.
