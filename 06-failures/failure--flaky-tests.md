# Failure: Flaky Tests

## What Makes a Test Flaky

A flaky test passes sometimes and fails sometimes with no code change. The test is non-deterministic — its outcome depends on something outside its control: time, shared state from other tests, asynchronous timing, random data, or external services. Flaky tests are worse than no tests: they erode trust in the test suite, cause developers to re-run failures until they pass ("just a flake"), and mask real failures.

## Async Timing Issues

The most common source of flakiness in UI tests. Code waits a fixed duration (`setTimeout(1000)`) hoping the operation completes by then. On a slow CI machine it doesn't. On a fast local machine it does.

**Wrong approach — fixed waits:**
```typescript
await page.click("#submit");
await new Promise(r => setTimeout(r, 1000)); // hope the modal appears
expect(screen.getByText("Success")).toBeInTheDocument();
```

**Right approach — wait for what you care about:**
```typescript
// Testing Library: use findBy* (async) not getBy* (sync) for things that appear async
const successMsg = await screen.findByText("Success"); // waits up to 1000ms by default
expect(successMsg).toBeInTheDocument();

// For custom async conditions, use waitFor
await waitFor(() => {
  expect(screen.getByRole("dialog")).toBeInTheDocument();
}, { timeout: 3000 });
```

`findBy*` queries use `waitFor` internally and poll until the element appears or the timeout expires. They are the right tool for anything that appears after an async operation. `getBy*` is synchronous — it throws immediately if the element isn't present, which is correct only when the element should already be there.

## Global State Leakage Between Tests

Tests that share global state — a module-level variable, a singleton, a real database, a shared in-memory store — can affect each other. One test modifies the global; the next test starts in a dirty state. Whether it fails depends on which test ran first, which depends on parallelism and scheduling.

```typescript
// BAD — module-level state bleeds between tests
let db = createDatabase(); // shared across all tests in the module

test("creates a user", async () => {
  await db.users.create({ name: "Alice" });
  // ...
});

test("lists users", async () => {
  const users = await db.users.findAll();
  expect(users).toHaveLength(1); // fails if "creates a user" ran first and left a row
});

// GOOD — reset state in beforeEach
beforeEach(async () => {
  await db.users.deleteMany({});
});
```

For database tests: use transactions that roll back after each test, or spin up a fresh database per test file.

## Date/Time Mocking

Tests that use `new Date()`, `Date.now()`, or `setTimeout` are time-dependent. They fail on New Year's Day, fail when clocks change, fail when the CI server is slow.

```typescript
// BAD — depends on real time
test("invoice is overdue after 30 days", () => {
  const invoice = createInvoice({ createdAt: new Date("2024-01-01") });
  expect(invoice.isOverdue()).toBe(true); // passes on Jan 31, fails on Jan 15
});

// GOOD — control time explicitly
import { vi } from "vitest";

test("invoice is overdue after 30 days", () => {
  vi.setSystemTime(new Date("2024-02-01")); // deterministic
  const invoice = createInvoice({ createdAt: new Date("2024-01-01") });
  expect(invoice.isOverdue()).toBe(true);
  vi.useRealTimers(); // restore after test
});
```

## Test Isolation Patterns

- **Reset mocks in `afterEach`** — `vi.clearAllMocks()` / `jest.clearAllMocks()` to prevent mock state from bleeding between tests.
- **Avoid `beforeAll` for mutable setup** — if multiple tests mutate the shared object, order matters. Use `beforeEach` to set up fresh state.
- **Use `randomUUID()` not sequential IDs** — sequential IDs collide when tests run in parallel.
- **Seed test data explicitly** — don't rely on data left by a previous test.
- **Mock external services** — an HTTP call to a real API is both slow and flaky. Use `msw` (Mock Service Worker) for consistent request interception.

## Key Rules

- **Never use `setTimeout` as a wait mechanism in tests** — use `findBy*`, `waitFor`, or explicit retry logic.
- **Each test must clean up after itself** — or be wrapped in a transaction that rolls back.
- **Mock `Date.now()` and `new Date()`** in any test that involves time-sensitive logic.
- **Flaky tests must be fixed, not re-run** — a "fix it later" flaky test is a known-false signal in your CI.
- **Run tests in random order** — tools like `--randomize` expose state leakage that consistent ordering hides.
- **Isolate tests from the filesystem and network** — use mocks for both; real I/O is slow and non-deterministic.
