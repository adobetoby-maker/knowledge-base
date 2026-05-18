# Principle: Test Pyramid

## Overview
The test pyramid describes the correct distribution of test types: many fast unit tests at the base, fewer integration tests in the middle, very few E2E tests at the top. Inverting this pyramid — having mostly E2E tests — is the most common cause of slow, flaky CI pipelines and developer feedback loops measured in minutes rather than seconds.

## The Three Levels

### Unit Tests (base — most numerous)
- Test a single function, class, or module in isolation
- No real database, no real HTTP, no filesystem
- Dependencies are replaced with test doubles (stubs, fakes, mocks)
- Runtime: ~10ms per test; suite of 500 tests runs in ~5s
- What they validate: pure logic, edge cases, error branches, data transformations

```typescript
// Pure unit test — no DB, no HTTP
test('calculates invoice total with tax', () => {
  const result = calculateTotal({ subtotal: 100_00, taxRate: 0.08 });
  expect(result.total).toBe(108_00);
  expect(result.tax).toBe(8_00);
});
```

### Integration Tests (middle — moderate)
- Test that components work together: real DB queries, real HTTP handlers, real file I/O
- Use a test database (seeded and torn down per test or per suite)
- Do NOT mock the database — that defeats the purpose
- Runtime: ~100ms per test; suite of 100 tests runs in ~10s
- What they validate: SQL queries are correct, HTTP status codes, auth middleware, DB constraints

```typescript
// Real Supabase/Postgres connection in test env
test('creates user and returns 201', async () => {
  const res = await app.inject({ method: 'POST', url: '/users', body: { email: 'a@b.com' } });
  expect(res.statusCode).toBe(201);
  const user = await db.users.findByEmail('a@b.com');
  expect(user).toBeDefined();
});
```

### E2E Tests (top — fewest)
- Test critical user journeys through the real browser against a real deployed app
- Playwright, Cypress, or similar
- Runtime: ~10s per test; slow, occasionally flaky (network, timing)
- What they validate: happy path sign-up, checkout, core business flow — not every edge case
- Rule of thumb: cover 3–5 critical journeys, not every feature

## The Inverted Pyramid Failure

When teams write mostly E2E tests:
- CI takes 30–60 minutes instead of 3–5 minutes
- Tests are flaky (timing issues, network variance) — "retry on failure" masks real bugs
- Failures are hard to diagnose — a failing E2E test could mean anything
- Developers run tests less frequently, so bugs compound before detection

## Cost Comparison

| Level | Time/test | Isolation | Feedback speed | Flakiness |
|---|---|---|---|---|
| Unit | ~10ms | Total | Immediate | Near zero |
| Integration | ~100ms | Partial | Fast | Low |
| E2E | ~10,000ms | None | Slow | Moderate |

## When to Write Each Type

**Write a unit test when:**
- Logic is complex (tax calculations, state machines, data transformations)
- Pure function with deterministic output
- Edge cases that are hard to trigger end-to-end

**Write an integration test when:**
- Testing a DB query or ORM usage
- Testing an HTTP route handler with real middleware
- Testing that two modules interact correctly

**Write an E2E test when:**
- It's a critical revenue or auth path
- The risk of it breaking undetected is catastrophic
- No other level can catch this class of bug

## Key Rules
- More unit tests than integration tests; far more integration tests than E2E tests
- Never mock the database in integration tests — that makes them unit tests
- E2E tests should only cover paths where business failure is most costly
- A failing E2E test suite in CI is a signal to push coverage down to integration or unit level
- Test speed is a feature; slow tests are not run and therefore provide no safety
