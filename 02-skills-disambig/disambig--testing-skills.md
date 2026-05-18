# Disambiguation: Testing Skills

**When:** Writing tests, reviewing coverage, or designing a test strategy.
**The trap:** Multiple overlapping test skills — pick the one that matches your actual need.

## The Testing Skills Map

| Skill | Best For |
|-------|---------|
| `/testing-patterns` | Jest + factory patterns, unit test design |
| `/e2e-testing-patterns` | Playwright end-to-end flow testing |
| `ruflo-testgen:tester` | TDD London School — write tests first, drive implementation |
| `pr-review-toolkit:pr-test-analyzer` | Review existing coverage, find gaps |
| `feature-dev:code-reviewer` | Includes test coverage in broader review |

## Decision Guide

### Writing new unit tests from scratch
→ `/testing-patterns`
```
The right skill when: you have working code and need to add test coverage.
Returns: Jest/Vitest test patterns, describe/it structure, assertion patterns, mocking.
```

### Building with TDD (tests before code)
→ `ruflo-testgen:tester`
```
The right skill when: starting a new module and want to define behavior via tests first.
Returns: Test suite that defines expected behavior, then implementation to make tests pass.
London School TDD: mock collaborators, test behavior not implementation.
```

### Testing a complete user flow
→ `/e2e-testing-patterns`
```
The right skill when: testing "user clicks book → confirmation email sent" as one flow.
Returns: Playwright test suites, page object patterns, test fixture setup.
```

### Checking if existing tests are good enough
→ `pr-review-toolkit:pr-test-analyzer`
```
The right skill when: tests exist but you want to know if they're adequate.
Returns: Coverage analysis, missing edge cases, incomplete assertions identified.
```

## jrs-auto-repair Test Stack
Vitest (not Jest) — use Vitest syntax:
```typescript
import { describe, it, expect, vi } from 'vitest'

describe('calculateInvoice', () => {
  it('applies tax to subtotal', () => {
    const result = calculateInvoice({ subtotal: 100, taxRate: 0.08 })
    expect(result.tax).toBe(8)
    expect(result.total).toBe(108)
  })
})
```
Run: `npx vitest run lib/invoices/calculate.test.ts`

## What to Test — Priority Order
```
1. Business logic functions (lib/) — pure functions → easiest to test
2. API routes — test the happy path + auth failure + invalid input
3. Database queries — test with a test database or mock
4. Components — test behavior (clicking, form submission) not visuals
5. E2E flows — test the most critical user journeys only
```

## What NOT to Test
```
- Next.js framework behavior (not your code)
- Third-party library internals
- Styling and layout (use visual QA instead)
- Types (TypeScript verifies those at compile time)
```
