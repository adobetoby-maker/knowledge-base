# Skill: testing-patterns

**Trigger:** Writing unit or integration tests. Need test structure, mocking patterns, factory functions, assertion best practices.
**Invoke:** `/testing-patterns`
**Returns:** Jest/Vitest patterns, factory functions, mock strategies, test organization, coverage guidance.

## When to Invoke
- Setting up tests for a new module
- Unsure how to mock external dependencies (fetch, Supabase, file system)
- Need factory functions for test data
- Setting up test coverage requirements
- Want to understand what to test vs what to skip

## Test Structure (Vitest/Jest)
```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

describe('calculateInvoice', () => {
  // Setup/teardown
  beforeEach(() => { /* runs before each test */ })
  afterEach(() => { vi.restoreAllMocks() })  // clean up mocks
  
  describe('with valid inputs', () => {
    it('calculates total with tax', () => {
      const result = calculateInvoice({ subtotal: 100, taxRate: 0.08 })
      expect(result.total).toBe(108)
    })
    
    it('rounds to cents', () => {
      const result = calculateInvoice({ subtotal: 33.33, taxRate: 0.1 })
      expect(result.total).toBe(36.66)  // not 36.663
    })
  })
  
  describe('with edge cases', () => {
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

## Factory Functions — Consistent Test Data
```typescript
// test/factories/user.factory.ts
let userCounter = 0

export function createUser(overrides: Partial<User> = {}): User {
  userCounter++
  return {
    id: `user-${userCounter}`,
    email: `user${userCounter}@example.com`,
    name: `Test User ${userCounter}`,
    createdAt: new Date('2026-01-01'),
    ...overrides  // caller can override any field
  }
}

// In tests:
const admin = createUser({ role: 'admin' })
const customer = createUser({ email: 'pablo@example.com' })
```

## Mocking

### Mock a module
```typescript
vi.mock('@/lib/supabase/server', () => ({
  createClient: () => ({
    from: () => ({
      select: () => ({
        eq: () => ({
          single: () => ({ data: { id: '1', name: 'Test' }, error: null })
        })
      })
    })
  })
}))
```

### Mock fetch
```typescript
global.fetch = vi.fn().mockResolvedValue({
  ok: true,
  json: async () => ({ id: '1', status: 'success' })
})

// Verify it was called
expect(fetch).toHaveBeenCalledWith('/api/orders', expect.objectContaining({
  method: 'POST'
}))
```

### Spy on a function
```typescript
const sendEmailSpy = vi.spyOn(emailService, 'send').mockResolvedValue(true)
await processOrder(order)
expect(sendEmailSpy).toHaveBeenCalledWith({
  to: order.email,
  subject: 'Order confirmed'
})
```

## What to Test (Priority Order)
```
1. Pure business logic (lib/) — easiest and most valuable
2. API route handlers — happy path + auth failure + invalid input
3. Utility functions — especially edge cases
4. React components — behavior, not rendering (click handlers, form submission)

Skip:
- Next.js/React internals
- Styling
- Third-party library internals
```

## What Skill Returns
Complete test patterns, Vitest configuration, snapshot testing, React Testing Library patterns, CI integration, and coverage configuration.
