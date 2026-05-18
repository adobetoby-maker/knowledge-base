# Disambiguation: What to Test and How

## Test Layer Decision

| What to test | Tool | Priority |
|-------------|------|----------|
| Pure business logic (lib/) | Vitest unit tests | HIGH |
| API route handlers | Vitest integration tests | HIGH |
| Auth behavior | Vitest with mocked Supabase | HIGH |
| React component rendering | React Testing Library | MEDIUM |
| Critical user flows | Playwright E2E | MEDIUM |
| Visual appearance | Screenshot/video review | REQUIRED for animated UI |
| SEO metadata | Manual PageSpeed check | MEDIUM |

## What Does NOT Need Tests

- Next.js routing itself (the framework is tested)
- Supabase client (it's a library — mock it, don't test it)
- Tailwind styles
- shadcn/ui components (pre-tested)
- Static data arrays (lib/articles.ts) unless business logic depends on them

## Unit Test Priority (jrs-auto-repair)

```
HIGH:
  lib/invoices/calculate.ts    ← financial calculations must be exact
  lib/adminAuth.ts             ← security logic
  lib/auth.ts                  ← authentication helpers

MEDIUM:
  lib/shopInfo.ts uniqueness   ← no duplicate slugs
  lib/articles.ts              ← no duplicate slugs (routing breaks)

LOW:
  UI components                ← tested via E2E
```

## Test File Location

Tests live adjacent to the code they test:

```
lib/
  invoices/
    calculate.ts
    calculate.test.ts    ← adjacent to implementation
  adminAuth.ts
  adminAuth.test.ts
```

Don't create a separate `tests/` directory. Keeping tests adjacent makes them easy to find and ensures they stay in sync with the code.

## Mock Strategy

```typescript
// Mock Supabase entirely in unit tests
vi.mock('@/lib/supabase/server', () => ({
  createClient: vi.fn().mockResolvedValue({
    auth: {
      getUser: vi.fn().mockResolvedValue({ data: { user: mockUser }, error: null })
    },
    from: vi.fn().mockReturnValue({
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      single: vi.fn().mockResolvedValue({ data: mockInvoice, error: null })
    })
  })
}))
```

Don't test against a real Supabase database in unit tests — it's slow, requires network, and creates test data pollution.

## E2E Test Priority

E2E tests are expensive to write and maintain. Only write them for:
1. The primary user journey (the thing that makes money)
2. Auth flows (most likely to break and hardest to debug without E2E)
3. Payment flows (if Stripe is integrated)

For visual testing (does it look right?):
```bash
node ~/screenshot.js 3007 0,540,810    # snapshots
node ~/record.js 3007                   # video for animations
```

These are faster than E2E tests and catch visual regressions.

## Test Coverage Target

For business logic files (`lib/`): 80%+ coverage.
For everything else: test the critical paths, not coverage percentages.

Coverage percentage is a lagging indicator. High coverage of trivial code and zero coverage of critical code is worse than 50% coverage of only the important code.

## When Tests Are Not Present

In projects without tests (`manage-worker-bee`, `silver-creek-logistics`, `orthobiologic-pathways`):
- Don't add tests mid-feature unless specifically requested
- If adding tests: start with the highest business risk logic only
- Follow jrs-auto-repair's Vitest setup as the template
