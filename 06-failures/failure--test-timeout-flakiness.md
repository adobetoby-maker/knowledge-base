# Failure: Test Timeout and Timing Flakiness

## Overview
Tests that use `setTimeout`, `sleep()`, or fixed time delays to wait for asynchronous behavior are fundamentally flaky. A 200ms sleep passes on a developer's M2 MacBook and fails intermittently in CI on a slower virtual machine. Flaky tests erode trust in the test suite: engineers start ignoring failures, re-running until green, and disabling "unreliable" tests. The root cause of timeout-based flakiness is always the same: waiting for time instead of waiting for state.

## The Root Cause

```typescript
// WRONG: waiting for time (the operation might take 300ms on CI)
await new Promise(r => setTimeout(r, 200));
expect(element).toBeVisible(); // might not be visible yet

// WRONG: arbitrary delay before assertion
await clickButton();
await sleep(500); // "just to be safe"
expect(mockFn).toHaveBeenCalled(); // sometimes fails on CI

// RIGHT: wait for the state you expect
await waitFor(() => expect(element).toBeVisible()); // polls until true or timeout
```

## Pattern 1: Control Time With Fake Timers

For code that uses `setTimeout`, `setInterval`, `Date.now()`, fake timers give the test full control:

```typescript
import { vi } from "vitest";

test("shows warning after 5 seconds of inactivity", async () => {
  vi.useFakeTimers();
  
  render(<InactivityWarning />);
  expect(screen.queryByText("Session expiring")).not.toBeInTheDocument();
  
  // Advance time by exactly 5 seconds — instant, no actual waiting
  vi.advanceTimersByTime(5000);
  
  expect(screen.getByText("Session expiring")).toBeInTheDocument();
  
  vi.useRealTimers(); // always restore
});
```

Fake timers make time-dependent tests fast (milliseconds instead of seconds) and 100% deterministic.

## Pattern 2: Wait for Element, Not Time

In DOM/React tests, use `waitFor` or `findBy` queries:

```typescript
// WRONG: arbitrary delay
await clickSubmitButton();
await sleep(300);
expect(screen.getByText("Success")).toBeInTheDocument(); // flaky

// RIGHT: wait for the element
await userEvent.click(screen.getByRole("button", { name: "Submit" }));
// waitFor polls until the expectation passes or times out
await waitFor(() => {
  expect(screen.getByText("Success")).toBeInTheDocument();
});

// Or use findBy* which has waitFor built in:
const successMessage = await screen.findByText("Success");
expect(successMessage).toBeInTheDocument();
```

## Pattern 3: Mock Animations for Test Stability

CSS animations and Framer Motion transitions can cause elements to be in intermediate states during assertions:

```css
/* In your test setup CSS or jest/vitest setup file */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

```typescript
// Vitest/Jest setup file
Object.defineProperty(window, "matchMedia", {
  writable: true,
  value: jest.fn().mockImplementation(query => ({
    matches: query === "(prefers-reduced-motion: reduce)", // always reduce motion in tests
    // ...
  })),
});
```

With zero-duration animations, elements reach their final state immediately.

## Pattern 4: Use Test Containers for Real DB

When testing database queries, use an actual database (not mocks) that is reset per test:

```typescript
// Wrong: mocking Prisma loses the ability to test actual query behavior
const prisma = { user: { findMany: vi.fn().mockResolvedValue([]) } };

// Right: use a real DB in a container, reset between tests
beforeEach(async () => {
  await prisma.$executeRaw`TRUNCATE users CASCADE`;
  await seedTestData(prisma);
});
```

Testcontainers, Docker Compose, or Supabase local provide real database behavior with test isolation.

## Pattern 5: Mock Network at the Handler Level

For HTTP calls, intercept at the handler level (MSW) rather than mocking `fetch` globally:

```typescript
// Wrong: mocking fetch returns a value but skips all real URL matching
global.fetch = vi.fn().mockResolvedValue({
  json: () => Promise.resolve({ users: [] }),
});

// Right: MSW intercepts specific routes
server.use(
  http.get("/api/users", () => HttpResponse.json({ users: [] })),
);
// Test code calls fetch("/api/users") normally
```

MSW handlers can be resolved immediately (no delay), making tests fast and deterministic.

## Diagnosing Flaky Tests

```bash
# Run the test 50 times to find intermittent failures
for i in {1..50}; do
  vitest run --reporter=verbose tests/MyComponent.test.tsx 2>&1 | grep -E "PASS|FAIL"
done

# Run with increased timeout to determine if it's a timing issue
vitest run --testTimeout=30000 # 30s timeout
# If it now passes: definitely a timing issue
# If it still fails: logic issue
```

## Key Rules
- Never use `setTimeout` or `sleep` in tests to wait for async operations
- Use `vi.useFakeTimers()` for code that uses `setTimeout`/`setInterval` — always restore with `vi.useRealTimers()` in `afterEach`
- Use `waitFor()` or `findBy*` for DOM state assertions — they poll until true
- Disable CSS animations in test environments via `prefers-reduced-motion: reduce`
- MSW for HTTP interception — no delays, deterministic responses
- Real databases (containers) for DB tests — never mock the ORM
- A test that requires `await sleep(500)` is testing the wrong thing — find what state to wait for instead
