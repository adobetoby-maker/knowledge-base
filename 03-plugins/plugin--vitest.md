# Plugin: Vitest

## What It Is

Vitest is the test framework used in `jrs-auto-repair`. It's Jest-compatible but runs on Vite, making it faster for modern projects. API is nearly identical to Jest.

## Running Tests

```bash
# From project root
npm test                                           # all tests (watch mode)
npx vitest run                                     # all tests (single run)
npx vitest run lib/invoices/calculate.test.ts      # single file
npx vitest run --reporter=verbose                  # detailed output
npx vitest coverage                                # with coverage report
```

## Test File Structure

```typescript
// lib/invoices/calculate.test.ts
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { calculateInvoice } from './calculate'

describe('calculateInvoice', () => {
  beforeEach(() => {
    // Runs before each test in this describe block
  })
  
  afterEach(() => {
    vi.restoreAllMocks()  // Clean up mocks after each test
  })
  
  describe('with standard tax rate', () => {
    it('calculates total correctly', () => {
      const result = calculateInvoice({ subtotal: 100, taxRate: 0.08 })
      expect(result.total).toBe(108)
      expect(result.tax).toBe(8)
    })
    
    it('rounds to two decimal places', () => {
      const result = calculateInvoice({ subtotal: 33.33, taxRate: 0.1 })
      expect(result.total).toBe(36.66)
    })
  })
  
  describe('edge cases', () => {
    it('handles zero subtotal', () => {
      const result = calculateInvoice({ subtotal: 0, taxRate: 0.08 })
      expect(result.total).toBe(0)
    })
    
    it('throws on negative subtotal', () => {
      expect(() => calculateInvoice({ subtotal: -1, taxRate: 0.08 }))
        .toThrow('Subtotal cannot be negative')
    })
  })
})
```

## Mocking

```typescript
import { vi } from 'vitest'

// Mock a module
vi.mock('@/lib/supabase/server', () => ({
  createClient: vi.fn().mockResolvedValue({
    from: () => ({
      select: () => ({
        eq: () => ({
          single: () => ({ data: { id: '1', name: 'Test' }, error: null })
        })
      })
    })
  })
}))

// Spy on a function
const emailSpy = vi.spyOn(emailService, 'send').mockResolvedValue(true)
await processInvoice(invoice)
expect(emailSpy).toHaveBeenCalledWith({ to: invoice.email })

// Mock fetch
global.fetch = vi.fn().mockResolvedValue({
  ok: true,
  json: async () => ({ status: 'success' })
})
```

## Factory Functions

Create consistent test data:

```typescript
// test/factories/invoice.factory.ts
let counter = 0

export function createInvoice(overrides: Partial<Invoice> = {}): Invoice {
  counter++
  return {
    id: `invoice-${counter}`,
    userId: `user-${counter}`,
    amount: 100.00,
    status: 'pending',
    createdAt: new Date('2026-01-01'),
    ...overrides
  }
}

// Usage:
const invoice = createInvoice({ amount: 250, status: 'paid' })
```

## What to Test in jrs-auto-repair

**Always test:**
- `lib/invoices/calculate.ts` — pure business logic
- `lib/adminAuth.ts` — verifyAdmin function
- `lib/articles.ts` — article slug uniqueness (prevent duplicate routes)
- API route handlers — auth failure returns 401, invalid input returns 400

**Skip:**
- Next.js routing itself
- Supabase client (mock it)
- React component rendering (use E2E for visual checks)

## Coverage Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: ['lib/**/*.ts'],
      exclude: ['lib/supabase/**'],  // skip supabase client files
      thresholds: {
        lines: 80,
        functions: 80,
      }
    }
  }
})
```

## Async Testing

```typescript
it('creates invoice in database', async () => {
  // All async tests must await
  const result = await createInvoice({ amount: 150 })
  expect(result.id).toBeDefined()
})

// Test rejection
it('throws on invalid amount', async () => {
  await expect(createInvoice({ amount: -1 })).rejects.toThrow()
})
```

## CI Integration

Tests run in CI automatically when the project has `npm test` in its build pipeline. Tests that fail block the deploy. Keep the test suite fast — aim for < 30 seconds total runtime.
